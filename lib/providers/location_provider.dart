import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/providers/auth_provider.dart';

part 'location_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;
String? get _uid => _db.auth.currentUser?.id;

// ---------------------------------------------------------------------------
// Location preferences — mirrors the profile's location columns
// ---------------------------------------------------------------------------

class LocationPrefs {
  const LocationPrefs({
    required this.locationConsent,
    required this.homeCity,
    required this.homeLat,
    required this.homeLng,
    required this.notifyNearbyTournaments,
    required this.nearbyRadiusKm,
  });

  final bool locationConsent;
  final String? homeCity;
  final double? homeLat;
  final double? homeLng;
  final bool notifyNearbyTournaments;
  final int nearbyRadiusKm;

  bool get hasLocation => homeLat != null && homeLng != null;

  factory LocationPrefs.fromProfile(Map<String, dynamic> p) => LocationPrefs(
        locationConsent: p['location_consent'] as bool? ?? false,
        homeCity: p['home_city'] as String?,
        homeLat: (p['home_lat'] as num?)?.toDouble(),
        homeLng: (p['home_lng'] as num?)?.toDouble(),
        notifyNearbyTournaments:
            p['notify_nearby_tournaments'] as bool? ?? false,
        nearbyRadiusKm: p['nearby_radius_km'] as int? ?? 50,
      );

  factory LocationPrefs.empty() => const LocationPrefs(
        locationConsent: false,
        homeCity: null,
        homeLat: null,
        homeLng: null,
        notifyNearbyTournaments: false,
        nearbyRadiusKm: 50,
      );
}

/// Reads location preferences from the current profile.
/// Invalidated by [LocationActions] after any update.
@riverpod
Future<LocationPrefs> locationPrefs(Ref ref) async {
  final uid = _uid;
  if (uid == null) return LocationPrefs.empty();

  final data = await _db
      .from('profiles')
      .select(
        'location_consent, home_city, home_lat, home_lng, '
        'notify_nearby_tournaments, nearby_radius_km',
      )
      .eq('id', uid)
      .maybeSingle();

  if (data == null) return LocationPrefs.empty();
  return LocationPrefs.fromProfile(data);
}

// ---------------------------------------------------------------------------
// Location actions notifier
// ---------------------------------------------------------------------------

@riverpod
class LocationActions extends _$LocationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Requests location permission, fetches GPS position, reverse-geocodes to
  /// a city name via Nominatim (free, EU-hosted, no API key required), rounds
  /// coordinates to 2 decimal places (~1.1 km precision) for data minimisation,
  /// and stores everything in the user's profile row.
  ///
  /// GDPR: only called after the user has explicitly accepted the consent
  /// sheet in Settings — the timestamp is recorded in [location_consent_at].
  Future<void> grantConsent() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid;
      if (uid == null) throw Exception('Not authenticated');

      // 1. Check/request platform location permission.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw const PermissionDeniedException('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
            'Location permission permanently denied');
      }

      // 2. Get current position (low accuracy is fine — we only need ~city level).
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 3. Round to 2 dp for data minimisation (~1.1 km precision).
      final lat = _round2(position.latitude);
      final lng = _round2(position.longitude);

      // 4. Reverse-geocode to city name via Nominatim (openstreetmap.org).
      //    Uses EU infrastructure and requires no API key.
      String? city;
      try {
        city = await _reverseGeocodeCity(lat, lng);
      } catch (_) {
        // Non-fatal — continue without city name if Nominatim is unavailable.
      }

      // 5. Persist to profile.
      await _db.from('profiles').update({
        'location_consent': true,
        'location_consent_at': DateTime.now().toUtc().toIso8601String(),
        'home_lat': lat,
        'home_lng': lng,
        'home_city': ?city,
      }).eq('id', uid);

      // 6. Refresh derived providers.
      ref.invalidate(locationPrefsProvider);
      ref.invalidate(currentProfileProvider);
    });
  }

  /// Revokes location consent and clears all stored location data from the
  /// profile. This satisfies GDPR Art. 7(3) (right to withdraw consent) and
  /// Art. 17 (right to erasure) for location data specifically.
  Future<void> revokeConsent() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid;
      if (uid == null) throw Exception('Not authenticated');

      await _db.from('profiles').update({
        'location_consent': false,
        'location_consent_at': null,
        'home_city': null,
        'home_lat': null,
        'home_lng': null,
        'notify_nearby_tournaments': false,
      }).eq('id', uid);

      ref.invalidate(locationPrefsProvider);
      ref.invalidate(currentProfileProvider);
    });
  }

  /// Toggles the "notify me about nearby tournaments" preference.
  Future<void> setNotifyNearby(bool value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid;
      if (uid == null) throw Exception('Not authenticated');

      await _db.from('profiles').update({
        'notify_nearby_tournaments': value,
      }).eq('id', uid);

      ref.invalidate(locationPrefsProvider);
    });
  }

  /// Updates the search radius (must be one of 25, 50, 100, 150 km).
  Future<void> setRadius(int radiusKm) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid;
      if (uid == null) throw Exception('Not authenticated');

      await _db.from('profiles').update({
        'nearby_radius_km': radiusKm,
      }).eq('id', uid);

      ref.invalidate(locationPrefsProvider);
    });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Calls Nominatim reverse-geocoding and returns the most useful locality name.
/// Nominatim is operated by OpenStreetMap Foundation with EU infrastructure.
/// Rate limit: 1 req/s — acceptable because this is called at most once per
/// user consent event.
Future<String?> _reverseGeocodeCity(double lat, double lng) async {
  final uri = Uri.https(
    'nominatim.openstreetmap.org',
    '/reverse',
    {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'jsonv2',
      'zoom': '10', // city level
      'addressdetails': '1',
    },
  );

  final response = await http.get(
    uri,
    headers: {
      // Nominatim policy requires a descriptive User-Agent.
      'User-Agent': 'RATED-Tennis-App/1.0 (contact@ratedtennis.app)',
    },
  );

  if (response.statusCode != 200) return null;

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final address = json['address'] as Map<String, dynamic>?;
  if (address == null) return null;

  // Prefer: city > town > village > county
  return (address['city'] ??
      address['town'] ??
      address['village'] ??
      address['county']) as String?;
}
