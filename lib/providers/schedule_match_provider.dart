import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'schedule_match_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;
String? get _uid => _db.auth.currentUser?.id;

/// Browse players whose ELO is within [eloRange] of the current user's ELO.
/// Defaults to ±1.5 (roughly ±150 on the old scale, proportional on 5–10).
@riverpod
Future<List<Map<String, dynamic>>> browsePlayers(
  Ref ref, {
  double centerElo = 7.5,
  double eloRange = 1.5,
}) async {
  final uid = _uid;
  final results = await _db
      .from('profiles')
      .select('id, display_name, avatar_url, elo_rating, elo_tier, club_id')
      .eq('is_public', true)
      .isFilter('deleted_at', null)
      .neq('id', uid ?? '')
      .gte('elo_rating', centerElo - eloRange)
      .lte('elo_rating', centerElo + eloRange)
      .order('elo_rating', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Schedule match actions
// ---------------------------------------------------------------------------

@riverpod
class ScheduleMatchActions extends _$ScheduleMatchActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Send a match request to [recipientId].
  Future<void> sendRequest({
    required String recipientId,
    required DateTime proposedAt,
    String? venueNote,
    String? message,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid!;
      await _db.from('match_requests').insert({
        'requester_id': uid,
        'recipient_id': recipientId,
        'proposed_at': proposedAt.toIso8601String(),
        if (venueNote != null && venueNote.isNotEmpty) 'venue_note': venueNote,
        if (message != null && message.isNotEmpty) 'message': message,
        'expires_at':
            DateTime.now().add(const Duration(hours: 72)).toIso8601String(),
      });
    });
  }
}
