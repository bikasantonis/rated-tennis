import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/app_bar_actions.dart';
import 'package:rated/widgets/pending_badge.dart';

/// SCR-10 — Tournament list with status tabs.
class TournamentsListScreen extends ConsumerStatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  ConsumerState<TournamentsListScreen> createState() =>
      _TournamentsListScreenState();
}

class _TournamentsListScreenState
    extends ConsumerState<TournamentsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _filterValues = [
    'registration_open',
    'in_progress',
    'completed',
    null,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filterValues.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final profileAsync = ref.watch(currentProfileProvider);
    final isOrganizer = profileAsync.asData?.value?.role.name == 'organizer' ||
        profileAsync.asData?.value?.role.name == 'admin';

    final openCount = ref
            .watch(tournamentsProvider(statusFilter: 'registration_open'))
            .asData
            ?.value
            .length ??
        0;
    final inProgressCount = ref
            .watch(tournamentsProvider(statusFilter: 'in_progress'))
            .asData
            ?.value
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tournamentsTitle),
        actions: const [AppBarActions()],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            TabWithBadge(label: l.tournamentsTabOpen, count: openCount),
            TabWithBadge(
                label: l.tournamentsTabInProgress, count: inProgressCount),
            Tab(text: l.tournamentsTabPast),
            Tab(text: l.tournamentsTabAll),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _filterValues
            .map((f) => _TournamentTab(statusFilter: f))
            .toList(),
      ),
      floatingActionButton: isOrganizer
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.organizerDashboard),
              icon: const Icon(Icons.add),
              label: Text(l.actionCreate),
            )
          : null,
    );
  }
}

class _TournamentTab extends ConsumerWidget {
  const _TournamentTab({required this.statusFilter});
  final String? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async =
        ref.watch(tournamentsProvider(statusFilter: statusFilter));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              l.tournamentsNone,
              style: TextStyle(color: AppColors.outline),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(tournamentsProvider(statusFilter: statusFilter)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TournamentCard(t: list[i]),
          ),
        );
      },
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.t});
  final Map<String, dynamic> t;

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = t['name'] as String? ?? '—';
    final status = t['status'] as String? ?? '';
    final format = t['format'] as String? ?? '';
    final startsAt = _formatDate(t['starts_at']);
    final eloMin = (t['elo_min'] as num?)?.toDouble() ?? 5.0;
    final eloMax = (t['elo_max'] as num?)?.toDouble() ?? 10.0;

    final statusColor = switch (status) {
      'registration_open' => AppColors.eloGain,
      'in_progress' => AppColors.primary,
      'completed' => AppColors.outline,
      _ => AppColors.outline,
    };

    final statusLabel = switch (status) {
      'registration_open' => l.tournamentStatusOpen,
      'in_progress' => l.tournamentStatusLive,
      'completed' => l.tournamentStatusCompleted,
      'draft' => l.tournamentStatusDraft,
      'cancelled' => l.tournamentStatusCancelled,
      _ => status,
    };

    final formatLabel = format == 'single_elimination'
        ? l.tournamentFormatSingleElim
        : l.tournamentFormatRoundRobin;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppRoutes.tournamentDetail.replaceFirst(':id', t['id'] as String),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(l.tournamentStarts(startsAt),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 16),
                  const Icon(Icons.format_list_bulleted,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(formatLabel,
                    style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.tournamentEloRange(
                    eloMin.toStringAsFixed(1), eloMax.toStringAsFixed(1)),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
