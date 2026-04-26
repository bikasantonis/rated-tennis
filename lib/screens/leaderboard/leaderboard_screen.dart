import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/providers/leaderboard_provider.dart';
import 'package:rated/providers/location_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/app_bar_actions.dart';
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
  bool _nearMe = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(locationPrefsProvider);
    final prefs = prefsAsync.asData?.value;

    // Nearby players data (only fetched when _nearMe is active and we have coords)
    final nearbyAsync = (_nearMe && prefs != null && prefs.hasLocation)
        ? ref.watch(nearbyPlayersProvider(
            lat: prefs.homeLat!,
            lng: prefs.homeLng!,
            radiusKm: prefs.nearbyRadiusKm,
            page: _page,
          ))
        : null;

    final pageAsync = (!_nearMe)
        ? ref.watch(leaderboardPageProvider(page: _page, clubId: _clubId))
        : null;

    final clubsAsync = ref.watch(clubsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.leaderboardTitle),
        actions: [
          // Near Me toggle button
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: _nearMe ? AppColors.primary : null,
            ),
            tooltip: l.leaderboardNearMe,
            onPressed: () {
              final hasLocation = prefs?.hasLocation ?? false;
              if (!hasLocation && !_nearMe) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.tournamentsLocationPromptBody),
                    action: SnackBarAction(
                      label: l.tournamentsGoToSettings,
                      onPressed: () => context.push('/settings'),
                    ),
                  ),
                );
                return;
              }
              setState(() {
                _nearMe = !_nearMe;
                _page = 0;
                if (_nearMe) {
                  _clubId = null;
                  _clubName = null;
                }
              });
            },
          ),
          if (!_nearMe)
            clubsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
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
          const AppBarActions(),
        ],
      ),
      body: _nearMe
          ? _buildNearMeBody(context, l, prefs, nearbyAsync)
          : _buildGlobalBody(context, l, pageAsync!),
    );
  }

  Widget _buildNearMeBody(
    BuildContext context,
    AppLocalizations l,
    LocationPrefs? prefs,
    AsyncValue<List<Map<String, dynamic>>>? nearbyAsync,
  ) {
    if (prefs == null || !prefs.hasLocation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 48, color: AppColors.outline),
              const SizedBox(height: 16),
              Text(l.tournamentsLocationPromptTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l.tournamentsLocationPromptBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.outline)),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => context.push('/settings'),
                child: Text(l.tournamentsGoToSettings),
              ),
            ],
          ),
        ),
      );
    }

    return nearbyAsync!.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(
              l.leaderboardNearMeEmpty(prefs.nearbyRadiusKm),
              style: const TextStyle(color: AppColors.outline),
            ),
          );
        }
        return Column(
          children: [
            _FilterChip(
              label: '${l.leaderboardNearMe} · ${prefs.nearbyRadiusKm} km',
              onRemove: () => setState(() {
                _nearMe = false;
                _page = 0;
              }),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(nearbyPlayersProvider(
                  lat: prefs.homeLat!,
                  lng: prefs.homeLng!,
                  radiusKm: prefs.nearbyRadiusKm,
                )),
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _LeaderboardRow(
                    rank: _page * kLeaderboardPageSize + i + 1,
                    row: rows[i],
                    distanceKm: (rows[i]['distance_km'] as num?)?.toDouble(),
                  ),
                ),
              ),
            ),
            _PaginationBar(
              page: _page,
              hasMore: rows.length == kLeaderboardPageSize,
              onPrev: _page > 0 ? () => setState(() => _page--) : null,
              onNext: rows.length == kLeaderboardPageSize
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalBody(
    BuildContext context,
    AppLocalizations l,
    AsyncValue<List<Map<String, dynamic>>> pageAsync,
  ) {
    return pageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty && _page == 0) {
          return Center(child: Text(l.leaderboardNoPlayers));
        }
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
                    rank: (rows[i]['global_rank'] as int?) ??
                        (_page * kLeaderboardPageSize + i + 1),
                    row: rows[i],
                  ),
                ),
              ),
            ),
            _PaginationBar(
              page: _page,
              hasMore: rows.length == kLeaderboardPageSize,
              onPrev: _page > 0 ? () => setState(() => _page--) : null,
              onNext: rows.length == kLeaderboardPageSize
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        );
      },
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
  const _LeaderboardRow({
    required this.rank,
    required this.row,
    this.distanceKm,
  });
  final int rank;
  final Map<String, dynamic> row;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final name = row['display_name'] as String? ?? '—';
    final elo = (row['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final tierStr = row['elo_tier'] as String? ?? 'beginner';
    final tier = EloTier.fromString(tierStr);

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
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            elo.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          if (distanceKm != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 10, color: AppColors.primary),
                const SizedBox(width: 2),
                Text(
                  AppLocalizations.of(context)!
                      .leaderboardDistanceKm(distanceKm!.toStringAsFixed(1)),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
        ],
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
