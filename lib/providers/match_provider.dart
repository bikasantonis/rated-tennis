import 'package:rated/models/match_result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'match_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;
String? get _uid => _db.auth.currentUser?.id;

// ---------------------------------------------------------------------------
// Opponent search (used in SubmitMatchScreen)
// ---------------------------------------------------------------------------

/// Returns profiles whose display_name contains [query], excluding current user.
/// Returns empty list for queries shorter than 2 characters.
@riverpod
Future<List<Map<String, dynamic>>> searchOpponents(
  Ref ref,
  String query,
) async {
  if (query.trim().length < 2) return [];
  final uid = _uid;
  final results = await _db
      .from('profiles')
      .select('id, display_name, elo_rating, elo_tier')
      .ilike('display_name', '%${query.trim()}%')
      .neq('id', uid ?? '')
      .eq('is_public', true)
      .limit(20);
  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Recent matches (Home feed)
// ---------------------------------------------------------------------------

/// Last 5 confirmed matches involving the current user, newest first.
@riverpod
Future<List<Map<String, dynamic>>> recentMatches(Ref ref) async {
  final uid = _uid;
  if (uid == null) return [];

  final results = await _db
      .from('match_results')
      .select(
        'id, winner_id, loser_id, score, match_type, status, played_at, '
        'winner:profiles!winner_id(display_name), '
        'loser:profiles!loser_id(display_name), '
        'elo_history(delta)',  // RLS returns only the current user's row
      )
      .or('winner_id.eq.$uid,loser_id.eq.$uid')
      .eq('status', 'confirmed')
      .order('played_at', ascending: false)
      .limit(5);

  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Inbox data
// ---------------------------------------------------------------------------

/// Match results submitted by the opponent that are awaiting the current
/// user's confirmation (i.e. current user is a participant but not submitter).
@riverpod
Future<List<Map<String, dynamic>>> pendingResults(Ref ref) async {
  final uid = _uid;
  if (uid == null) return [];

  final results = await _db
      .from('match_results')
      .select(
        'id, submitter_id, winner_id, loser_id, score, match_type, '
        'status, played_at, created_at, '
        'winner:profiles!winner_id(display_name), '
        'loser:profiles!loser_id(display_name)',
      )
      .or('winner_id.eq.$uid,loser_id.eq.$uid')
      .neq('submitter_id', uid)
      .eq('status', 'pending')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(results as List);
}

/// Match requests sent to the current user that are still pending.
@riverpod
Future<List<Map<String, dynamic>>> pendingRequests(Ref ref) async {
  final uid = _uid;
  if (uid == null) return [];

  final results = await _db
      .from('match_requests')
      .select(
        'id, requester_id, proposed_at, venue_note, message, '
        'status, expires_at, created_at, '
        'requester:profiles!requester_id(display_name, elo_rating, elo_tier)',
      )
      .eq('recipient_id', uid)
      .eq('status', 'pending')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Match actions notifier
// ---------------------------------------------------------------------------

@riverpod
class MatchActions extends _$MatchActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Submit a new friendly match result (status = 'pending', awaits opponent confirmation).
  Future<void> submitMatch({
    required String opponentId,
    required bool currentUserWon,
    required List<SetScore> sets,
    required DateTime playedAt,
    required MatchFormat format,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid!;
      final winnerId = currentUserWon ? uid : opponentId;
      final loserId = currentUserWon ? opponentId : uid;

      final score = sets
          .map((s) => {'winner': s.winner, 'loser': s.loser})
          .toList();

      try {
        await _db.from('match_results').insert({
          'submitter_id': uid,
          'winner_id': winnerId,
          'loser_id': loserId,
          'score': score,
          'match_type': 'friendly',
          'format': format.dbValue,
          'played_at': playedAt.toIso8601String().substring(0, 10),
        });
      } on PostgrestException catch (e) {
        if (e.message.contains('rate_limit_exceeded')) {
          throw Exception(
              'You have reached the limit of 20 match submissions per hour. Please try again later.');
        }
        rethrow;
      }
    });
  }

  /// Confirm a match result — calls the elo-recalculate Edge Function.
  Future<void> confirmMatch(String matchId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _db.functions.invoke(
        'elo-recalculate',
        body: {'match_id': matchId},
      );
      if (response.status != 200) {
        throw Exception(
          (response.data as Map?)?['error'] ?? 'Failed to confirm match',
        );
      }
    });
  }

  /// Dispute a match result with a corrected score.
  Future<void> disputeMatch(
    String matchId,
    List<SetScore> disputeScore,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid!;
      await _db.from('match_results').update({
        'status': 'disputed',
        'disputed_by': uid,
        'dispute_score': disputeScore.map((s) => s.toJson()).toList(),
      }).eq('id', matchId);
    });
  }

  /// Accept a match request.
  Future<void> acceptRequest(String requestId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('match_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);
    });
  }

  /// Decline a match request.
  Future<void> declineRequest(String requestId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('match_requests')
          .update({'status': 'declined'})
          .eq('id', requestId);
    });
  }
}

// ---------------------------------------------------------------------------
// Friendly match ELO eligibility check
// ---------------------------------------------------------------------------

/// Returns true when a friendly match between the current user and [opponentId]
/// would be ELO-excluded because the tier gap exceeds 1.5 steps.
///
/// Tier is computed as floor(elo_rating / 0.5) × 0.5, matching the DB logic in
/// apply_elo_changes. The DB enforces this independently; this provider is for
/// surfacing a warning in the UI before the match is submitted.
@riverpod
Future<bool> friendlyEloExcluded(Ref ref, String opponentId) async {
  final uid = _uid;
  if (uid == null) return false;

  final rows = await _db
      .from('profiles')
      .select('id, elo_rating')
      .inFilter('id', [uid, opponentId]);

  final ratings = {
    for (final r in List<Map<String, dynamic>>.from(rows as List))
      r['id'] as String: (r['elo_rating'] as num).toDouble()
  };

  final myRating = ratings[uid] ?? 5.0;
  final opponentRating = ratings[opponentId] ?? 5.0;

  final myTier = (myRating / 0.5).floor() * 0.5;
  final opponentTier = (opponentRating / 0.5).floor() * 0.5;

  return (myTier - opponentTier).abs() > 1.5;
}
