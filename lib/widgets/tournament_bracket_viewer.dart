import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/models/bracket_match.dart';
import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// Horizontally-scrollable single-elimination bracket viewer.
///
/// Reads [bracketMatchesProvider] and draws each round as a column of
/// [_MatchCard] widgets.  If [isOrganizer] is true and the tournament is
/// in-progress, every ready (both-slots-filled, no winner) match shows a
/// "Record result" action.
class TournamentBracketViewer extends ConsumerWidget {
  const TournamentBracketViewer({
    required this.tournamentId,
    required this.isOrganizer,
    super.key,
  });

  final String tournamentId;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracketAsync = ref.watch(bracketMatchesProvider(tournamentId));
    return bracketAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (matches) {
        if (matches.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.bracketNotGenerated,
              style: TextStyle(color: AppColors.outline),
            ),
          );
        }
        return _BracketGrid(
          matches: matches,
          tournamentId: tournamentId,
          isOrganizer: isOrganizer,
        );
      },
    );
  }
}

class _BracketGrid extends StatelessWidget {
  const _BracketGrid({
    required this.matches,
    required this.tournamentId,
    required this.isOrganizer,
  });

  final List<BracketMatch> matches;
  final String tournamentId;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context) {
    final rounds = matches.map((m) => m.roundNumber).toSet().toList()..sort();
    final totalRounds = rounds.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rounds.map((round) {
          final roundMatches =
              matches.where((m) => m.roundNumber == round).toList();
          return _RoundColumn(
            roundNumber: round,
            totalRounds: totalRounds,
            matches: roundMatches,
            tournamentId: tournamentId,
            isOrganizer: isOrganizer,
          );
        }).toList(),
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.roundNumber,
    required this.totalRounds,
    required this.matches,
    required this.tournamentId,
    required this.isOrganizer,
  });

  final int roundNumber;
  final int totalRounds;
  final List<BracketMatch> matches;
  final String tournamentId;
  final bool isOrganizer;

  String _roundLabel(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (roundNumber == totalRounds) return l.bracketFinal;
    if (roundNumber == totalRounds - 1) return l.bracketSemifinal;
    return l.bracketRound(roundNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Round header
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roundLabel(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          ...matches.map(
            (m) => _MatchCard(
              match: m,
              tournamentId: tournamentId,
              totalRounds: totalRounds,
              isOrganizer: isOrganizer,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({
    required this.match,
    required this.tournamentId,
    required this.totalRounds,
    required this.isOrganizer,
  });

  final BracketMatch match;
  final String tournamentId;
  final int totalRounds;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final actionState = ref.watch(tournamentActionsProvider);
    final isLoading = actionState is AsyncLoading;

    final p1Name = match.player1Name ?? (match.player1Id == null ? l.bracketBye : '—');
    final p2Name = match.player2Name ?? (match.player2Id == null ? l.bracketBye : '—');

    final p1Won = match.winnerId == match.player1Id && match.player1Id != null;
    final p2Won = match.winnerId == match.player2Id && match.player2Id != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerRow(
              name: p1Name,
              isWinner: p1Won,
              isBye: match.player1Id == null && !match.isBye,
            ),
            Divider(height: 10, color: AppColors.outline.withAlpha(80)),
            _PlayerRow(
              name: p2Name,
              isWinner: p2Won,
              isBye: match.player2Id == null && !match.isBye,
            ),
            // Record result button for organiser
            if (isOrganizer && match.isReady && !match.isBye) ...[
              const SizedBox(height: 8),
              _RecordResultButton(
                match: match,
                tournamentId: tournamentId,
                totalRounds: totalRounds,
                isLoading: isLoading,
                p1Name: p1Name,
                p2Name: p2Name,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.isWinner,
    required this.isBye,
  });

  final String name;
  final bool isWinner;
  final bool isBye;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isWinner)
          const Icon(Icons.emoji_events, size: 14, color: AppColors.eloGain)
        else
          const SizedBox(width: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight:
                      isWinner ? FontWeight.bold : FontWeight.normal,
                  color: isBye
                      ? AppColors.outline
                      : isWinner
                          ? AppColors.eloGain
                          : AppColors.onSurface,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RecordResultButton extends ConsumerWidget {
  const _RecordResultButton({
    required this.match,
    required this.tournamentId,
    required this.totalRounds,
    required this.isLoading,
    required this.p1Name,
    required this.p2Name,
  });

  final BracketMatch match;
  final String tournamentId;
  final int totalRounds;
  final bool isLoading;
  final String p1Name;
  final String p2Name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
          textStyle: const TextStyle(fontSize: 11),
        ),
        onPressed: isLoading
            ? null
            : () => _showResultDialog(context, ref, l),
        child: Text(l.bracketRecordResult),
      ),
    );
  }

  Future<void> _showResultDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final winnerId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bracketSelectWinner),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p1Name),
              onTap: () => Navigator.pop(ctx, match.player1Id),
            ),
            ListTile(
              title: Text(p2Name),
              onTap: () => Navigator.pop(ctx, match.player2Id),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionCancel),
          ),
        ],
      ),
    );
    if (winnerId == null || !context.mounted) return;
    await ref.read(tournamentActionsProvider.notifier).recordBracketResult(
          tournamentId,
          match.id,
          winnerId,
          match.roundNumber,
          match.matchNumber,
          totalRounds,
        );
    if (!context.mounted) return;
    ref.invalidate(bracketMatchesProvider(tournamentId));
    final st = ref.read(tournamentActionsProvider);
    if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.error.toString())),
      );
    }
  }
}

/// Compute the total number of rounds for a bracket of [n] players.
int bracketTotalRounds(int n) {
  final slots = _nextPow2Viewer(n);
  return (math.log(slots) / math.log(2)).round();
}

int _nextPow2Viewer(int n) {
  var p = 1;
  while (p < n) { p *= 2; }
  return p;
}
