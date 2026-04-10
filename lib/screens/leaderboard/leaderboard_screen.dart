import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/providers/leaderboard_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/tier_badge.dart';
import 'package:rated/models/profile.dart';

/// SCR-05 — Leaderboard: paginated (50/page), optional club filter.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _page = 0;
  String? _clubId;
  String? _clubName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pageAsync = ref.watch(
      leaderboardPageProvider(page: _page, clubId: _clubId),
    );
    final clubsAsync = ref.watch(clubsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.leaderboardTitle),
        actions: [
          clubsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (clubs) => clubs.isEmpty
                ? const SizedBox.shrink()
                : _ClubFilterButton(
                    clubs: clubs,
                    selectedClubId: _clubId,
                    selectedClubName: _clubName,
                    onSelected: (id, name) => setState(() {
                      _clubId = id;
                      _clubName = name;
                      _page = 0;
                    }),
                  ),
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty && _page == 0) {
            return Center(child: Text(l.leaderboardNoPlayers));
          }
          final startRank = _page * kLeaderboardPageSize;
          return Column(
            children: [
              if (_clubId != null)
                _FilterChip(
                  label: _clubName ?? _clubId!,
                  onRemove: () => setState(() {
                    _clubId = null;
                    _clubName = null;
                    _page = 0;
                  }),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(leaderboardPageProvider),
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _LeaderboardRow(
                      rank: startRank + i + 1,
                      row: rows[i],
                    ),
                  ),
                ),
              ),
              _PaginationBar(
                page: _page,
                hasMore: rows.length == kLeaderboardPageSize,
                onPrev: _page > 0
                    ? () => setState(() => _page--)
                    : null,
                onNext: rows.length == kLeaderboardPageSize
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Club filter button ────────────────────────────────────────────────────────

class _ClubFilterButton extends StatelessWidget {
  const _ClubFilterButton({
    required this.clubs,
    required this.selectedClubId,
    required this.selectedClubName,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> clubs;
  final String? selectedClubId;
  final String? selectedClubName;
  final void Function(String? id, String? name) onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list,
        color: selectedClubId != null ? AppColors.primary : null,
      ),
      tooltip: l.leaderboardFilterByClub,
      onSelected: (id) {
        final club = clubs.firstWhere((c) => c['id'] == id);
        onSelected(id, club['name'] as String?);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          child: Text(l.leaderboardAllClubs),
        ),
        ...clubs.map(
          (c) => PopupMenuItem(
            value: c['id'] as String,
            child: Text(c['name'] as String? ?? c['id'] as String),
          ),
        ),
      ],
    );
  }
}

// ── Active filter chip ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(label),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: onRemove,
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.12),
            labelStyle: const TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.row});
  final int rank;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row['display_name'] as String? ?? '—';
    final elo = (row['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final tierStr = row['elo_tier'] as String? ?? 'beginner';
    final tier = EloTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => EloTier.beginner,
    );

    final isTopThree = rank <= 3;
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.outline,
    };

    return ListTile(
      onTap: () => context.push('/leaderboard/${row['id']}'),
      leading: CircleAvatar(
        backgroundColor:
            isTopThree ? rankColor.withValues(alpha: 0.15) : null,
        child: Text(
          '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTopThree ? rankColor : AppColors.onSurface,
          ),
        ),
      ),
      title: Text(name),
      subtitle: TierBadge(tier: tier, small: true),
      trailing: Text(
        elo.toStringAsFixed(1),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
      ),
    );
  }
}

// ── Pagination bar ────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.hasMore,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final bool hasMore;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Text(l.leaderboardPage(page + 1),
              style: Theme.of(context).textTheme.bodyMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
