import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'leaderboard_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;

const int kLeaderboardPageSize = 50;

/// Returns one page of leaderboard rows, optionally filtered by [clubId].
/// [page] is 0-based.
/// Delegates to the `get_leaderboard_page` RPC so that RATED players
/// (elo_rating = 10.0) are ranked by prestige_score and the pre-computed
/// global_rank column is correct across pages.
@riverpod
Future<List<Map<String, dynamic>>> leaderboardPage(
  Ref ref, {
  int page = 0,
  String? clubId,
}) async {
  final params = <String, dynamic>{
    'p_page': page,
    'p_page_size': kLeaderboardPageSize,
  };
  if (clubId != null) params['p_club_id'] = clubId;

  final results = await _db.rpc('get_leaderboard_page', params: params);

  return List<Map<String, dynamic>>.from(results as List);
}

/// Players within [radiusKm] of [lat]/[lng] who have location consent.
/// Returns rows with [distance_km] field, ordered by ascending distance.
@riverpod
Future<List<Map<String, dynamic>>> nearbyPlayers(
  Ref ref, {
  required double lat,
  required double lng,
  int radiusKm = 50,
  int page = 0,
}) async {
  final results = await _db.rpc('nearby_players', params: {
    'p_lat': lat,
    'p_lng': lng,
    'p_radius_km': radiusKm,
    'p_limit': kLeaderboardPageSize,
    'p_offset': page * kLeaderboardPageSize,
  });
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
