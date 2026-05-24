import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'profile_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Fetches any player's public profile.
@riverpod
Future<Map<String, dynamic>?> playerProfile(Ref ref, String playerId) async {
  final data = await _db
      .from('profiles')
      .select(
        'id, display_name, avatar_url, club_id, elo_rating, elo_tier, role, '
        'matches_played, matches_won, preferred_language, is_public, '
        'questionnaire_done, peak_elo, home_city, location_consent, '
        'created_at, updated_at',
      )
      .eq('id', playerId)
      .maybeSingle();
  return data;
}

/// Last 20 ELO history entries for the sparkline (newest first).
@riverpod
Future<List<Map<String, dynamic>>> eloHistory(Ref ref, String playerId) async {
  final results = await _db
      .from('elo_history')
      .select('id, elo_before, elo_after, delta, event_type, created_at')
      .eq('player_id', playerId)
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(results as List);
}

/// Last 10 confirmed matches for a player's match history tab.
@riverpod
Future<List<Map<String, dynamic>>> playerMatches(
    Ref ref, String playerId) async {
  final results = await _db
      .from('match_results')
      .select(
        'id, winner_id, loser_id, score, match_type, status, played_at, '
        'winner:profiles!winner_id(display_name), '
        'loser:profiles!loser_id(display_name), '
        'elo_history(delta), ' // RLS returns only the authenticated user's row
        'tournament:tournaments!tournament_id(name)',
      )
      .or('winner_id.eq.$playerId,loser_id.eq.$playerId')
      .eq('status', 'confirmed')
      .order('played_at', ascending: false)
      .limit(10);
  return List<Map<String, dynamic>>.from(results as List);
}

/// Questionnaire answers for a player (visible if profile is public).
@riverpod
Future<Map<String, dynamic>?> playerQuestionnaire(
    Ref ref, String playerId) async {
  final data = await _db
      .from('questionnaire_responses')
      .select(
        'playing_frequency, self_assessed_level, '
        'years_playing, preferred_surface, has_competed',
      )
      .eq('player_id', playerId)
      .maybeSingle();
  return data;
}

/// Tournament registration history for a player (last 20, newest first).
@riverpod
Future<List<Map<String, dynamic>>> playerTournamentHistory(
    Ref ref, String playerId) async {
  final results = await _db
      .from('tournament_registrations')
      .select(
        'status, registered_at, '
        'tournament:tournaments!tournament_id('
        'id, name, status, starts_at, ends_at, format'
        ')',
      )
      .eq('player_id', playerId)
      .order('registered_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(results as List);
}

/// Global rank of a player among all public profiles.
@riverpod
Future<int?> playerGlobalRank(Ref ref, String playerId) async {
  final result =
      await _db.rpc('get_player_rank', params: {'p_id': playerId});
  return result as int?;
}

// ---------------------------------------------------------------------------
// Profile edit actions (own profile only)
// ---------------------------------------------------------------------------

@riverpod
class ProfileEditActions extends _$ProfileEditActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> updateDisplayName(String playerId, String name) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'display_name': name})
          .eq('id', playerId);
    });
    if (ref.mounted) state = result;
  }

  Future<void> updateLanguage(String playerId, String lang) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'preferred_language': lang})
          .eq('id', playerId);
    });
    if (ref.mounted) state = result;
  }

  /// Uploads avatar bytes to Supabase Storage and updates the profile row.
  Future<void> updateAvatar(
      String playerId, Uint8List bytes, String ext) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final path = '$playerId/avatar.$ext';
      final storage = _db.storage.from('avatars');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final url = storage.getPublicUrl(path);
      await _db
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', playerId);
    });
    if (ref.mounted) state = result;
    if (result.hasError) throw result.error!;
  }

  /// Deletes the avatar file from Storage and clears the profile row.
  Future<void> removeAvatar(String playerId, String ext) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final path = '$playerId/avatar.$ext';
      await _db.storage.from('avatars').remove([path]);
      await _db
          .from('profiles')
          .update({'avatar_url': null}).eq('id', playerId);
    });
    if (ref.mounted) state = result;
    if (result.hasError) throw result.error!;
  }

  Future<void> updateCourtTheme(String playerId, String themeKey) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'court_theme': themeKey})
          .eq('id', playerId);
    });
    if (ref.mounted) state = result;
  }

  Future<void> softDelete(String playerId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', playerId);
    });
    if (ref.mounted) state = result;
  }
}
