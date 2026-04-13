import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/models/bracket_match.dart';

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

/// Tournaments owned by the current user, optionally filtered by status.
@riverpod
Future<List<Map<String, dynamic>>> myTournaments(
  Ref ref, {
  String? statusFilter,
}) async {
  final uid = _uid;
  if (uid == null) return [];
  var query = _db
      .from('tournaments')
      .select('id, name, format, status, starts_at, ends_at, '
          'elo_min, elo_max, max_players, registration_open, elo_multiplier, '
          'club_id, organizer_id')
      .eq('organizer_id', uid);

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

/// Registrations for a tournament (approved only — for bracket / participant list).
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

/// All registrations for a tournament regardless of status (organiser management).
@riverpod
Future<List<Map<String, dynamic>>> allTournamentRegistrations(
    Ref ref, String tournamentId) async {
  final results = await _db
      .from('tournament_registrations')
      .select(
        'id, player_id, status, seed, registered_at, '
        'player:profiles!player_id(display_name, elo_rating, elo_tier)',
      )
      .eq('tournament_id', tournamentId)
      .order('registered_at', ascending: true);
  return List<Map<String, dynamic>>.from(results as List);
}

/// Bracket matches for a tournament, grouped by round.
@riverpod
Future<List<BracketMatch>> bracketMatches(
    Ref ref, String tournamentId) async {
  final results = await _db
      .from('tournament_bracket_matches')
      .select(
        'id, tournament_id, round_number, match_number, '
        'player1_id, player2_id, winner_id, is_bye, '
        'p1:profiles!player1_id(display_name), '
        'p2:profiles!player2_id(display_name), '
        'w:profiles!winner_id(display_name)',
      )
      .eq('tournament_id', tournamentId)
      .order('round_number', ascending: true)
      .order('match_number', ascending: true);
  return (results as List)
      .map((r) => BracketMatch.fromMap(r as Map<String, dynamic>))
      .toList();
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
        'club_id': ?clubId,
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

  /// Change tournament status (draft → registration_open → in_progress → completed).
  Future<void> updateTournamentStatus(
      String tournamentId, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('tournaments')
          .update({'status': status}).eq('id', tournamentId);
    });
  }

  /// Seed admitted players by ELO, generate all bracket rounds, then
  /// set tournament status to 'in_progress'.
  Future<void> generateBracket(String tournamentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Fetch admitted registrations sorted by ELO descending.
      final regsRaw = await _db
          .from('tournament_registrations')
          .select('id, player_id, elo_at_registration')
          .eq('tournament_id', tournamentId)
          .eq('status', 'approved')
          .order('elo_at_registration', ascending: false);
      final regs = List<Map<String, dynamic>>.from(regsRaw as List);
      if (regs.length < 2) {
        throw Exception('Need at least 2 approved players to generate a bracket.');
      }

      // 2. Compute bracket dimensions.
      final n = regs.length;
      final totalSlots = _nextPow2(n);
      final totalRounds = math.log(totalSlots) ~/ math.log(2);

      // 3. Assign seed numbers and update registrations.
      for (var i = 0; i < regs.length; i++) {
        await _db
            .from('tournament_registrations')
            .update({'seed': i + 1}).eq('id', regs[i]['id'] as String);
      }

      // 4. Build a helper: seed index → player_id (null = bye).
      String? playerAt(int seedIndex) {
        if (seedIndex < regs.length) {
          return regs[seedIndex]['player_id'] as String;
        }
        return null;
      }

      // 5. Generate all rounds (all later-round slots start empty).
      final rows = <Map<String, dynamic>>[];
      for (var round = 1; round <= totalRounds; round++) {
        final matchesInRound = totalSlots ~/ math.pow(2, round).toInt();
        for (var match = 1; match <= matchesInRound; match++) {
          if (round == 1) {
            // Standard bracket seeding: match k pairs seed k vs seed (slots+1-k).
            final seed1Index = match - 1;
            final seed2Index = totalSlots - match;
            final p1 = playerAt(seed1Index);
            final p2 = playerAt(seed2Index);
            final isBye = p1 == null || p2 == null;
            rows.add({
              'tournament_id': tournamentId,
              'round_number': round,
              'match_number': match,
              'player1_id': p1,
              'player2_id': p2,
              'winner_id': isBye ? (p1 ?? p2) : null,
              'is_bye': isBye,
            });
          } else {
            rows.add({
              'tournament_id': tournamentId,
              'round_number': round,
              'match_number': match,
              'is_bye': false,
            });
          }
        }
      }

      await _db.from('tournament_bracket_matches').insert(rows);

      // 6. Advance auto-bye winners into round 2.
      if (totalRounds > 1) {
        final byeMatches = rows.where((r) =>
            r['round_number'] == 1 &&
            r['is_bye'] == true &&
            r['winner_id'] != null);
        for (final bye in byeMatches) {
          final matchNum = bye['match_number'] as int;
          final nextMatch = ((matchNum - 1) ~/ 2) + 1;
          final isOddSlot = matchNum % 2 == 1;
          await _db
              .from('tournament_bracket_matches')
              .update({
                if (isOddSlot)
                  'player1_id': bye['winner_id']
                else
                  'player2_id': bye['winner_id'],
              })
              .eq('tournament_id', tournamentId)
              .eq('round_number', 2)
              .eq('match_number', nextMatch);
        }
      }

      // 7. Mark tournament in_progress.
      await _db
          .from('tournaments')
          .update({'status': 'in_progress'}).eq('id', tournamentId);
    });
  }

  /// Record the winner of a bracket match and advance them to the next round.
  Future<void> recordBracketResult(
      String tournamentId, String matchId, String winnerId,
      int roundNumber, int matchNumber, int totalRounds) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Update the current match.
      await _db
          .from('tournament_bracket_matches')
          .update({'winner_id': winnerId})
          .eq('id', matchId);

      // If this is not the final, advance winner to the next round.
      if (roundNumber < totalRounds) {
        final nextRound = roundNumber + 1;
        final nextMatch = ((matchNumber - 1) ~/ 2) + 1;
        final isOddSlot = matchNumber % 2 == 1;
        await _db
            .from('tournament_bracket_matches')
            .update({
              if (isOddSlot)
                'player1_id': winnerId
              else
                'player2_id': winnerId,
            })
            .eq('tournament_id', tournamentId)
            .eq('round_number', nextRound)
            .eq('match_number', nextMatch);
      }
    });
  }
}

int _nextPow2(int n) {
  var p = 1;
  while (p < n) {
    p *= 2;
  }
  return p;
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
