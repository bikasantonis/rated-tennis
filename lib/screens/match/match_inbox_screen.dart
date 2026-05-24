import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/models/match_result.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/app_bar_actions.dart';
import 'package:rated/widgets/pending_badge.dart';

/// SCR-08 — Match inbox.
/// Tab 1: Pending results submitted by opponent (confirm / dispute).
/// Tab 2: Incoming match requests (accept / decline).
class MatchInboxScreen extends ConsumerWidget {
  const MatchInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final resultsCount =
        ref.watch(pendingResultsProvider).asData?.value.length ?? 0;
    final requestsCount =
        ref.watch(pendingRequestsProvider).asData?.value.length ?? 0;

    return Theme(
      data: Theme.of(context).copyWith(
        tabBarTheme: const TabBarThemeData(
          indicatorColor: AppColors.wGreen,
          labelColor: AppColors.wGreen,
        ),
      ),
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.inboxTitle),
          actions: const [AppBarActions()],
          bottom: TabBar(
            tabs: [
              TabWithBadge(label: l.inboxTabToConfirm, count: resultsCount),
              TabWithBadge(label: l.inboxTabRequests, count: requestsCount),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingResultsTab(),
            _PendingRequestsTab(),
          ],
        ),
      ),
    ),
    );
  }
}

// ── Tab 1: Pending results ────────────────────────────────────────────────────

class _PendingResultsTab extends ConsumerWidget {
  const _PendingResultsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(pendingResultsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (results) {
        if (results.isEmpty) {
          return _EmptyState(
            icon: Icons.check_circle_outline,
            message: l.inboxNoPendingResults,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingResultsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _PendingResultCard(match: results[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _PendingResultCard extends StatelessWidget {
  const _PendingResultCard({required this.match, required this.ref});
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis, size: 18, color: AppColors.wGreen),
                const SizedBox(width: 8),
                Text(
                  l.inboxWonDef(winnerName, loserName),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatScore(match['score']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l.inboxPlayedOn(_formatDate(match['played_at'])),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _showDisputeDialog(context, match['id'] as String),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.wPurple,
                      side: const BorderSide(color: AppColors.wPurple),
                    ),
                    child: Text(l.actionDispute),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _confirm(context, match['id'] as String),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.wGreen,
                        foregroundColor: Colors.white),
                    child: Text(l.actionConfirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, String matchId) async {
    await ref.read(matchActionsProvider.notifier).confirmMatch(matchId);
    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      final st = ref.read(matchActionsProvider);
      if (st is AsyncData) {
        ref.invalidate(pendingResultsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.inboxConfirmSuccess)),
        );
      } else if (st is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(st.error.toString())),
        );
      }
    }
  }

  Future<void> _showDisputeDialog(
      BuildContext context, String matchId) async {
    final sets = [_DisputeSetEntry(), _DisputeSetEntry()];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DisputeDialog(matchId: matchId, sets: sets),
    );
    if (confirmed == true && context.mounted) {
      ref.invalidate(pendingResultsProvider);
    }
  }
}

class _DisputeSetEntry {
  final winnerCtrl = TextEditingController();
  final loserCtrl = TextEditingController();
}

class _DisputeDialog extends ConsumerStatefulWidget {
  const _DisputeDialog({required this.matchId, required this.sets});
  final String matchId;
  final List<_DisputeSetEntry> sets;

  @override
  ConsumerState<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends ConsumerState<_DisputeDialog> {
  late final List<_DisputeSetEntry> _sets;

  @override
  void initState() {
    super.initState();
    _sets = widget.sets;
  }

  Future<void> _submit() async {
    final score = _sets
        .where((s) =>
            s.winnerCtrl.text.isNotEmpty && s.loserCtrl.text.isNotEmpty)
        .map((s) => SetScore(
              winner: int.tryParse(s.winnerCtrl.text) ?? 0,
              loser: int.tryParse(s.loserCtrl.text) ?? 0,
            ))
        .toList();

    await ref
        .read(matchActionsProvider.notifier)
        .disputeMatch(widget.matchId, score);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.inboxDisputeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.inboxDisputeEnterScore),
          const SizedBox(height: 12),
          ..._sets.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${l.setLabel(e.key + 1)}:  '),
                    Expanded(
                      child: TextField(
                        controller: e.value.winnerCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: e.value.loserCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.wPurple,
              foregroundColor: Colors.white),
          child: Text(l.inboxDisputeSubmit),
        ),
      ],
    );
  }
}

// ── Tab 2: Pending requests ───────────────────────────────────────────────────

class _PendingRequestsTab extends ConsumerWidget {
  const _PendingRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(pendingRequestsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (requests) {
        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.calendar_today_outlined,
            message: l.inboxNoPendingRequests,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _RequestCard(request: requests[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.ref});
  final Map<String, dynamic> request;
  final WidgetRef ref;

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final requester = request['requester'] as Map?;
    final name = requester?['display_name'] as String? ?? 'Player';
    final elo = (requester?['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final proposed = _formatDate(request['proposed_at']);
    final message = request['message'] as String?;
    final venue = request['venue_note'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(name[0])),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      l.eloLabel(elo.toStringAsFixed(1)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.wGreen),
                const SizedBox(width: 6),
                Text(l.inboxProposedDate(proposed),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (venue != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.wGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(venue,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                '"$message"',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _respond(context, request['id'] as String, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.wPurple,
                      side: const BorderSide(color: AppColors.wPurple),
                    ),
                    child: Text(l.actionDecline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        _respond(context, request['id'] as String, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.wGreen,
                        foregroundColor: Colors.white),
                    child: Text(l.actionAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
      BuildContext context, String requestId, bool accept) async {
    if (accept) {
      await ref.read(matchActionsProvider.notifier).acceptRequest(requestId);
    } else {
      await ref.read(matchActionsProvider.notifier).declineRequest(requestId);
    }
    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      ref.invalidate(pendingRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? l.inboxRequestAccepted : l.inboxRequestDeclined),
        ),
      );
    }
  }
}

// ── Shared empty / error states ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Error: $message',
        style: TextStyle(color: AppColors.error),
      ),
    );
  }
}
