import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// SCR-14 — Admin-only dispute resolution panel.
class DisputeResolutionScreen extends ConsumerWidget {
  const DisputeResolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(disputedMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.disputeTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gavel_outlined,
                      size: 48, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text(l.disputeNoDisputes,
                      style: TextStyle(color: AppColors.outline)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(disputedMatchesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _DisputeCard(match: matches[i], ref: ref),
            ),
          );
        },
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.match, required this.ref});
  final Map<String, dynamic> match;
  final WidgetRef ref;

  String _formatScore(dynamic score) {
    if (score is! List) return '—';
    return score
        .map((s) { final m = s as Map; return '${m['winner']}–${m['loser']}'; })
        .join(', ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final winnerName =
        (match['winner'] as Map?)?['display_name'] as String? ?? 'Winner';
    final loserName =
        (match['loser'] as Map?)?['display_name'] as String? ?? 'Loser';
    final originalScore = _formatScore(match['score']);
    final disputedScore = _formatScore(match['dispute_score']);
    final actionState = ref.watch(disputeActionsProvider);
    final isLoading = actionState is AsyncLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.inboxWonDef(winnerName, loserName),
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
            const SizedBox(height: 10),
            _ScoreRow(
              label: l.disputeOriginalScore,
              score: originalScore,
              color: AppColors.outline,
            ),
            const SizedBox(height: 4),
            _ScoreRow(
              label: l.disputeDisputedScore,
              score: disputedScore,
              color: AppColors.tertiary,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => _resolve(context, match['id'] as String,
                            approve: false),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: Text(l.disputeKeepOriginal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.outline,
                      side: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => _resolve(context, match['id'] as String,
                            approve: true),
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(l.disputeAcceptDispute),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, String matchId,
      {required bool approve}) async {
    if (approve) {
      await ref.read(disputeActionsProvider.notifier).approveDispute(matchId);
    } else {
      await ref.read(disputeActionsProvider.notifier).overrideDispute(matchId);
    }
    if (!context.mounted) return;
    final l = AppLocalizations.of(context)!;
    final st = ref.read(disputeActionsProvider);
    if (st is AsyncData) {
      ref.invalidate(disputedMatchesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? l.disputeAcceptedSuccess
              : l.disputeOverriddenSuccess),
        ),
      );
    } else if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.error.toString())),
      );
    }
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(
      {required this.label, required this.score, required this.color});
  final String label;
  final String score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.outline)),
        Text(score,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
