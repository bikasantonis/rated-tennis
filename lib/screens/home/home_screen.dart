import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/elo_score_card.dart';

/// SCR-04 — Home / Dashboard.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.homeTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(recentMatchesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EloScoreCard(profile: profile),
                const SizedBox(height: 24),
                Text(
                  l.homeRecentMatches,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _RecentMatchesList(currentUserId: profile.id),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'schedule',
            onPressed: () => context.push(AppRoutes.scheduleMatch),
            tooltip: l.homeScheduleMatch,
            child: const Icon(Icons.calendar_today_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'submit',
            onPressed: () => context.push(AppRoutes.submitMatch),
            icon: const Icon(Icons.add),
            label: Text(l.homeSubmitMatch),
          ),
        ],
      ),
    );
  }
}

// ── Recent matches list ───────────────────────────────────────────────────────

class _RecentMatchesList extends ConsumerWidget {
  const _RecentMatchesList({required this.currentUserId});
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(recentMatchesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(l.errorCouldNotLoadMatches,
          style: TextStyle(color: AppColors.error)),
      data: (matches) {
        if (matches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l.homeNoMatches,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.outline),
              ),
            ),
          );
        }
        return Column(
          children: matches
              .map((m) => _MatchTile(match: m, currentUserId: currentUserId))
              .toList(),
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.currentUserId});
  final Map<String, dynamic> match;
  final String currentUserId;

  String _formatScore(dynamic score) {
    if (score is! List) return '—';
    return score.map((s) { final m = s as Map; return '${m['winner']}–${m['loser']}'; }).join(', ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  double? get _eloDelta {
    final history = match['elo_history'] as List?;
    if (history == null || history.isEmpty) return null;
    return (history.first as Map?)?['delta'] as double?;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final winnerId = match['winner_id'] as String?;
    final won = winnerId == currentUserId;
    final winnerName =
        (match['winner'] as Map?)?['display_name'] as String? ?? 'Winner';
    final loserName =
        (match['loser'] as Map?)?['display_name'] as String? ?? 'Loser';
    final opponentName = won ? loserName : winnerName;
    final delta = _eloDelta;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: won
              ? AppColors.eloGain.withValues(alpha: 0.15)
              : AppColors.eloLoss.withValues(alpha: 0.15),
          child: Icon(
            won ? Icons.emoji_events_outlined : Icons.sports_tennis,
            color: won ? AppColors.eloGain : AppColors.eloLoss,
            size: 20,
          ),
        ),
        title: Text(
          won ? l.homeMatchWonVs(opponentName) : l.homeMatchLostVs(opponentName),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(_formatScore(match['score'])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (delta != null)
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                style: TextStyle(
                  color: delta >= 0 ? AppColors.eloGain : AppColors.eloLoss,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            Text(
              _formatDate(match['played_at']),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
