import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/auth_provider.dart';
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
                    onSelect: (p) => setState(() => _selected = p),
                  )
                : _RequestFormView(
                    opponent: _selected!,
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

// ── Player list ───────────────────────────────────────────────────────────────

class _PlayerListView extends StatelessWidget {
  const _PlayerListView(
      {required this.players, required this.onSelect});
  final List<Map<String, dynamic>> players;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (players.isEmpty) {
      return Center(child: Text(l.scheduleNoPlayersInRange));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = players[i];
        final name = p['display_name'] as String? ?? '—';
        final elo = (p['elo_rating'] as num?)?.toDouble() ?? 5.0;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(name[0])),
            title: Text(name),
            subtitle: Text(l.eloLabel(elo.toStringAsFixed(1))),
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
    required this.proposedAt,
    required this.venueCtrl,
    required this.messageCtrl,
    required this.onPickDate,
    required this.onBack,
    required this.onSend,
    required this.actionState,
  });

  final Map<String, dynamic> opponent;
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
              subtitle: Text(l.eloLabel(elo.toStringAsFixed(1))),
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
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  ${pad(dt.hour)}:${pad(dt.minute)}';
  }
}
