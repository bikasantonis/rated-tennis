import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/providers/schedule_match_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// SCR-09 — Schedule a match: browse players ±1.5 ELO, send request.
class ScheduleMatchScreen extends ConsumerStatefulWidget {
  const ScheduleMatchScreen({super.key});

  @override
  ConsumerState<ScheduleMatchScreen> createState() =>
      _ScheduleMatchScreenState();
}

class _ScheduleMatchScreenState extends ConsumerState<ScheduleMatchScreen> {
  Map<String, dynamic>? _selected;
  DateTime? _proposedAt;
  final _venueCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _venueCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.scheduleTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          final playersAsync = ref.watch(
            browsePlayersProvider(centerElo: profile.eloRating),
          );
          return playersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (players) => _selected == null
                ? _PlayerListView(
                    players: players,
                    myElo: profile.eloRating,
                    onSelect: (p) => setState(() => _selected = p),
                  )
                : _RequestFormView(
                    opponent: _selected!,
                    myElo: profile.eloRating,
                    proposedAt: _proposedAt,
                    venueCtrl: _venueCtrl,
                    messageCtrl: _messageCtrl,
                    onPickDate: () => _pickDate(context),
                    onBack: () => setState(() => _selected = null),
                    onSend: () => _send(context),
                    actionState: ref.watch(scheduleMatchActionsProvider),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateTimePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _proposedAt = picked);
  }

  Future<void> _send(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    if (_proposedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.errorPickDate)),
      );
      return;
    }
    await ref.read(scheduleMatchActionsProvider.notifier).sendRequest(
          recipientId: _selected!['id'] as String,
          proposedAt: _proposedAt!,
          venueNote: _venueCtrl.text,
          message: _messageCtrl.text,
        );
    if (!context.mounted) return;
    final st = ref.read(scheduleMatchActionsProvider);
    if (st is AsyncData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.scheduleRequestSent)),
      );
      context.pop();
    } else if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.error.toString())),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helper — date + time picker
// ---------------------------------------------------------------------------

Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Max ELO points gained by winning a friendly vs [opponentElo].
/// Same K=0.15, D=1.67 formula as backend (migration 019_numeric_tiers.sql).
double _calcMaxPoints(double myElo, double opponentElo) {
  const k = 0.15;
  const d = 1.67;
  final eWinner = 1.0 / (1.0 + pow(10.0, (opponentElo - myElo) / d));
  return (k * (1.0 - eWinner)).clamp(0.01, 0.20);
}

// ── Player list ───────────────────────────────────────────────────────────────

class _PlayerListView extends ConsumerStatefulWidget {
  const _PlayerListView({
    required this.players,
    required this.myElo,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> players;
  final double myElo;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  ConsumerState<_PlayerListView> createState() => _PlayerListViewState();
}

class _PlayerListViewState extends ConsumerState<_PlayerListView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l.scheduleSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _query.length >= 2
              ? _SearchResults(
                  query: _query,
                  myElo: widget.myElo,
                  onSelect: widget.onSelect,
                )
              : _BrowseList(
                  players: widget.players,
                  myElo: widget.myElo,
                  onSelect: widget.onSelect,
                ),
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.myElo,
    required this.onSelect,
  });
  final String query;
  final double myElo;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final resultsAsync = ref.watch(searchOpponentsProvider(query));
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (results) {
        if (results.isEmpty) {
          return Center(child: Text(l.scheduleNoSearchResults));
        }
        return _PlayerTileList(
          players: results,
          myElo: myElo,
          onSelect: onSelect,
        );
      },
    );
  }
}

class _BrowseList extends StatelessWidget {
  const _BrowseList({
    required this.players,
    required this.myElo,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> players;
  final double myElo;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (players.isEmpty) {
      return Center(child: Text(l.scheduleNoPlayersInRange));
    }
    return _PlayerTileList(players: players, myElo: myElo, onSelect: onSelect);
  }
}

class _PlayerTileList extends StatelessWidget {
  const _PlayerTileList({
    required this.players,
    required this.myElo,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> players;
  final double myElo;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = players[i];
        final name = p['display_name'] as String? ?? '—';
        final elo = (p['elo_rating'] as num?)?.toDouble() ?? 5.0;
        final maxPts = _calcMaxPoints(myElo, elo);
        final ptsLabel = maxPts.toStringAsFixed(2);
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(name[0])),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.eloLabel(elo.toStringAsFixed(1))),
                const SizedBox(height: 2),
                Text(
                  l.scheduleMaxWinPoints(ptsLabel),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: () => onSelect(p),
              style: FilledButton.styleFrom(
                minimumSize: const Size(80, 36),
              ),
              child: Text(l.actionRequest),
            ),
          ),
        );
      },
    );
  }
}

// ── Request form ──────────────────────────────────────────────────────────────

class _RequestFormView extends StatelessWidget {
  const _RequestFormView({
    required this.opponent,
    required this.myElo,
    required this.proposedAt,
    required this.venueCtrl,
    required this.messageCtrl,
    required this.onPickDate,
    required this.onBack,
    required this.onSend,
    required this.actionState,
  });

  final Map<String, dynamic> opponent;
  final double myElo;
  final DateTime? proposedAt;
  final TextEditingController venueCtrl;
  final TextEditingController messageCtrl;
  final VoidCallback onPickDate;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final AsyncValue<void> actionState;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = opponent['display_name'] as String? ?? '—';
    final elo = (opponent['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final isLoading = actionState is AsyncLoading;
    final maxPts = _calcMaxPoints(myElo, elo);
    final ptsLabel = maxPts.toStringAsFixed(2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(name[0])),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.eloLabel(elo.toStringAsFixed(1))),
                  const SizedBox(height: 2),
                  Text(
                    l.scheduleMaxWinPoints(ptsLabel),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: onBack,
                child: Text(l.actionChange),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(l.scheduleProposedDateTime,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    proposedAt == null
                        ? l.schedulePickDateTime
                        : _formatDt(proposedAt!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: proposedAt == null
                              ? AppColors.outline
                              : AppColors.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: venueCtrl,
            decoration: InputDecoration(
              labelText: l.scheduleVenueLabel,
              hintText: l.scheduleVenueHint,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: messageCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l.scheduleMessageLabel,
              hintText: l.scheduleMessageHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),

          FilledButton(
            onPressed: isLoading ? null : onSend,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(l.actionSendRequest),
          ),
        ],
      ),
    );
  }

  String _formatDt(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  ${pad(dt.hour)}:${pad(dt.minute)}';
  }
}
