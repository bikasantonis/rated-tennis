import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'tournament_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;
String? get _uid => _db.auth.currentUser?.id;

/// All tournaments, optionally filtered by status tab.
/// [statusFilter]: null = all, or one of 'registration_open','in_progress','completed'
@riverpod
Future<List<Map<String, dynamic>>> tournaments(
  Ref ref, {
  String? statusFilter,
}) async {
  var query = _db
      .from('tournaments')
      .select('id, name, format, status, starts_at, ends_at, '
          'elo_min, elo_max, max_players, registration_open, elo_multiplier, '
          'club_id, organizer_id');

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final results = await query.order('starts_at', ascending: false);
  return List<Map<String, dynamic>>.from(results as List);
}

/// Single tournament detail + registrations count.
@riverpod
Future<Map<String, dynamic>?> tournamentDetail(
    Ref ref, String tournamentId) async {
  final data = await _db
      .from('tournaments')
      .select(
        'id, name, description, format, status, starts_at, ends_at, '
        'elo_min, elo_max, max_players, registration_open, elo_multiplier, '
        'club_id, organizer_id, created_at, '
        'registrations:tournament_registrations(count)',
      )
      .eq('id', tournamentId)
      .maybeSingle();
  return data;
}

/// Registrations for a tournament (for bracket / participant list).
@riverpod
Future<List<Map<String, dynamic>>> tournamentRegistrations(
    Ref ref, String tournamentId) async {
  final results = await _db
      .from('tournament_registrations')
      .select(
        'id, player_id, status, seed, registered_at, '
        'player:profiles!player_id(display_name, elo_rating, elo_tier)',
      )
      .eq('tournament_id', tournamentId)
      .eq('status', 'approved')
      .order('seed', ascending: true);
  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Organizer actions
// ---------------------------------------------------------------------------

@riverpod
class TournamentActions extends _$TournamentActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> createTournament({
    required String name,
    String? description,
    required String format,
    required double eloMin,
    required double eloMax,
    required int maxPlayers,
    required DateTime startsAt,
    required double eloMultiplier,
    String? clubId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('tournaments').insert({
        'organizer_id': _uid!,
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'format': format,
        'elo_min': eloMin,
        'elo_max': eloMax,
        'max_players': maxPlayers,
        'starts_at': startsAt.toIso8601String(),
        'elo_multiplier': eloMultiplier,
        if (clubId != null) 'club_id': clubId,
        'status': 'draft',
      });
    });
  }

  Future<void> updateRegistrationStatus(
      String registrationId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('tournament_registrations')
          .update({'status': status})
          .eq('id', registrationId);
    });
  }

  Future<void> registerForTournament(String tournamentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('tournament_registrations').insert({
        'tournament_id': tournamentId,
        'player_id': _uid!,
      });
    });
  }
}

// ---------------------------------------------------------------------------
// Admin — dispute resolution
// ---------------------------------------------------------------------------

@riverpod
Future<List<Map<String, dynamic>>> disputedMatches(Ref ref) async {
  final results = await _db
      .from('match_results')
      .select(
        'id, winner_id, loser_id, score, dispute_score, disputed_by, '
        'played_at, created_at, '
        'winner:profiles!winner_id(display_name), '
        'loser:profiles!loser_id(display_name)',
      )
      .eq('status', 'disputed')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(results as List);
}

@riverpod
class DisputeActions extends _$DisputeActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Admin approves the disputed score and confirms the match.
  Future<void> approveDispute(String matchId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid!;
      // Copy dispute_score → score, set resolved
      final match = await _db
          .from('match_results')
          .select('dispute_score')
          .eq('id', matchId)
          .single();
      await _db.from('match_results').update({
        'score': match['dispute_score'],
        'status': 'confirmed',
        'confirmed_at': DateTime.now().toIso8601String(),
        'resolved_by': uid,
      }).eq('id', matchId);
      await _db.rpc('apply_elo_changes', params: {'p_match_id': matchId});
    });
  }

  /// Admin overrides: keeps original score, marks as overridden.
  Future<void> overrideDispute(String matchId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = _uid!;
      await _db.from('match_results').update({
        'status': 'overridden',
        'confirmed_at': DateTime.now().toIso8601String(),
        'resolved_by': uid,
      }).eq('id', matchId);
      await _db.rpc('apply_elo_changes', params: {'p_match_id': matchId});
    });
  }
}
