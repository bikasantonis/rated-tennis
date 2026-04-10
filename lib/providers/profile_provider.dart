import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'profile_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Fetches any player's public profile + ELO history for the sparkline.
@riverpod
Future<Map<String, dynamic>?> playerProfile(Ref ref, String playerId) async {
  final data = await _db
      .from('profiles')
      .select(
        'id, display_name, avatar_url, club_id, elo_rating, elo_tier, role, '
        'matches_played, matches_won, preferred_language, is_public, '
        'questionnaire_done, created_at, updated_at',
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
        'elo_history(delta)',  // RLS returns only the authenticated user's row
      )
      .or('winner_id.eq.$playerId,loser_id.eq.$playerId')
      .eq('status', 'confirmed')
      .order('played_at', ascending: false)
      .limit(10);
  return List<Map<String, dynamic>>.from(results as List);
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
    state = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'display_name': name})
          .eq('id', playerId);
    });
  }

  Future<void> updateLanguage(String playerId, String lang) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'preferred_language': lang})
          .eq('id', playerId);
    });
  }

  Future<void> softDelete(String playerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', playerId);
    });
  }
}
