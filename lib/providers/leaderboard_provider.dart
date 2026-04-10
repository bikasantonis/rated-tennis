import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'leaderboard_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;

const int kLeaderboardPageSize = 50;

/// Returns one page of leaderboard rows, optionally filtered by [clubId].
/// [page] is 0-based.
@riverpod
Future<List<Map<String, dynamic>>> leaderboardPage(
  Ref ref, {
  int page = 0,
  String? clubId,
}) async {
  var query = _db
      .from('profiles')
      .select('id, display_name, avatar_url, elo_rating, elo_tier, '
          'matches_played, matches_won, club_id')
      .eq('is_public', true)
      .isFilter('deleted_at', null);

  if (clubId != null) {
    query = query.eq('club_id', clubId);
  }

  final results = await query
      .order('elo_rating', ascending: false)
      .range(
        page * kLeaderboardPageSize,
        (page + 1) * kLeaderboardPageSize - 1,
      );

  return List<Map<String, dynamic>>.from(results as List);
}

/// Returns all clubs (id + name) for the filter dropdown.
@riverpod
Future<List<Map<String, dynamic>>> clubs(Ref ref) async {
  final results = await _db
      .from('clubs')
      .select('id, name')
      .order('name', ascending: true);
  return List<Map<String, dynamic>>.from(results as List);
}
