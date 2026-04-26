import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rated/models/profile.dart';
import 'package:rated/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

// ---------------------------------------------------------------------------
// Auth status for router
// ---------------------------------------------------------------------------

enum AuthStatus { loading, authenticated, unauthenticated }

/// A [ChangeNotifier] the router uses via [GoRouter.refreshListenable].
///
/// Reads [Supabase.instance.client.auth.currentSession] synchronously on
/// construction (available immediately after [Supabase.initialize] in main),
/// then subscribes to [onAuthStateChange] for subsequent updates.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    final existing = Supabase.instance.client.auth.currentSession;

    if (existing != null) {
      _session = existing;
      _status = AuthStatus.authenticated;
      NotificationService.instance.identifyUser(existing.user.id);
    } else {
      _status = AuthStatus.unauthenticated;
    }

    // Enforce a minimum splash display of ~1 second.
    _splashReady = false;
    Future<void>.delayed(const Duration(seconds: 1), () {
      _splashReady = true;
      notifyListeners();
    });

    _subscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session != null) {
        NotificationService.instance.identifyUser(session.user.id);
      } else {
        NotificationService.instance.clearUser();
      }
      _session = session;
      _status = session != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;
  Session? _session;
  AuthStatus _status = AuthStatus.loading;
  bool _splashReady = false;

  Session? get session => _session;
  AuthStatus get status => _status;
  bool get splashReady => _splashReady;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@riverpod
AuthChangeNotifier authNotifier(Ref ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
}

// ---------------------------------------------------------------------------
// Session stream
// ---------------------------------------------------------------------------

/// Emits the current Supabase [Session] or null when logged out.
/// Also keeps OneSignal user identity in sync with Supabase auth state.
@riverpod
Stream<Session?> authState(Ref ref) =>
    Supabase.instance.client.auth.onAuthStateChange.map((event) {
      final session = event.session;
      if (session != null) {
        NotificationService.instance.identifyUser(session.user.id);
      } else {
        NotificationService.instance.clearUser();
      }
      return session;
    });

// ---------------------------------------------------------------------------
// Current profile
// ---------------------------------------------------------------------------

/// Fetches the authenticated user's profile row from Supabase.
@riverpod
Future<Profile?> currentProfile(Ref ref) async {
  final session = await ref.watch(authStateProvider.future);
  if (session == null) return null;

  final data = await Supabase.instance.client
      .from('profiles')
      .select(
        'id, display_name, avatar_url, club_id, elo_rating, elo_tier, role, '
        'matches_played, matches_won, preferred_language, is_public, '
        'questionnaire_done, peak_elo, '
        'location_consent, location_consent_at, home_city, home_lat, home_lng, '
        'notify_nearby_tournaments, nearby_radius_km, '
        'deleted_at, created_at, updated_at',
      )
      .eq('id', session.user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromJson(data);
}

// ---------------------------------------------------------------------------
// Auth actions
// ---------------------------------------------------------------------------

@riverpod
class AuthActions extends _$AuthActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  SupabaseClient get _client => Supabase.instance.client;

  /// Email + password sign-in.
  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
  }

  /// Email + password registration.
  /// [displayName] is stored in user metadata so the DB trigger can set it.
  /// [consentTimestamp] is the UTC time the user ticked the GDPR checkbox.
  Future<void> signUpWithEmail(
    String email,
    String password,
    String displayName,
    DateTime consentTimestamp,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'gdpr_consent_at': consentTimestamp.toIso8601String(),
        },
      ),
    );
  }

  /// Google OAuth — browser redirect on web, system sheet on native.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        // On web: omit redirectTo so Supabase uses the current page URL
        // automatically — avoids port-specific whitelisting in the dashboard.
        // On native: deep-link scheme handles the callback.
        redirectTo: kIsWeb ? null : 'io.supabase.rated://login-callback',
      ),
    );
  }

  /// Apple Sign-In — native only (sign_in_with_apple package does not support web).
  /// On web this method should never be called — callers must guard with [kIsWeb].
  Future<void> signInWithApple() async {
    if (kIsWeb) return; // safety guard
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );
    });
  }

  /// Sends a password-reset email via Supabase.
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _client.auth.resetPasswordForEmail(email),
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _client.auth.signOut());
  }

  /// Updates the authenticated user's password.
  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// GDPR Art. 17 — scrubs PII and hard-deletes the auth user via Edge Function.
  Future<void> anonymiseAccount() async {
    await _client.functions.invoke('anonymise-account');
  }
}
