import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/tier_badge.dart';
import 'package:rated/widgets/tournament_bracket_viewer.dart';
import 'package:rated/widgets/error_state_widget.dart';
import 'package:rated/models/profile.dart';

/// SCR-11 — Tournament detail: info, participants, bracket, registration CTA.
class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final profileAsync = ref.watch(currentProfileProvider);

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.tournamentDetailTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l.tournamentDetailTitle)),
        body: const ErrorStateWidget(),
      ),
      data: (t) {
        if (t == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.tournamentDetailTitle)),
            body: Center(child: Text(l.errorTournamentNotFound)),
          );
        }

        final status = t['status'] as String? ?? '';
        final hasBracket =
            status == 'in_progress' || status == 'completed';
        final organizerId = t['organizer_id'] as String?;
        final currentUid = switch (profileAsync) {
          AsyncData(:final value) => value?.id,
          _ => null,
        };
        final isOrganizer = currentUid != null && currentUid == organizerId;

        return DefaultTabController(
          length: hasBracket ? 3 : 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.tournamentDetailTitle),
              bottom: TabBar(
                tabs: [
                  const Tab(icon: Icon(Icons.info_outline)),
                  Tab(
                    icon: const Icon(Icons.people_outline),
                    text: l.tournamentDetailParticipants,
                  ),
                  if (hasBracket)
                    Tab(
                      icon: const Icon(Icons.account_tree_outlined),
                      text: l.bracketTitle,
                    ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // ── Info tab ────────────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(tournamentDetailProvider(tournamentId)),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoCard(t: t),
                      const SizedBox(height: 16),
                      _RegistrationCta(
                        t: t,
                        tournamentId: tournamentId,
                        profileAsync: profileAsync,
                        ref: ref,
                      ),
                    ],
                  ),
                ),

                // ── Participants tab ─────────────────────────────────────────
                _ParticipantsTab(tournamentId: tournamentId),

                // ── Bracket tab (only when in_progress or completed) ─────────
                if (hasBracket)
                  TournamentBracketViewer(
                    tournamentId: tournamentId,
                    isOrganizer: isOrganizer,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Participants tab ─────────────────────────────────────────────────────────

class _ParticipantsTab extends ConsumerWidget {
  const _ParticipantsTab({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final regsAsync = ref.watch(tournamentRegistrationsProvider(tournamentId));
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(tournamentRegistrationsProvider(tournamentId)),
      child: regsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorStateWidget(),
        data: (regs) => regs.isEmpty
            ? Center(
                child: Text(l.tournamentDetailNoParticipants,
                    style: TextStyle(color: AppColors.outline)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: regs.length,
                itemBuilder: (_, i) => _ParticipantTile(r: regs[i]),
              ),
      ),
    );
  }
}

// ── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.t});
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
    final description = t['description'] as String?;
    final format = t['format'] as String? ?? '';
    final startsAt = _formatDate(t['starts_at']);
    final endsAt = _formatDate(t['ends_at']);
    final eloMin = (t['elo_min'] as num?)?.toDouble() ?? 5.0;
    final eloMax = (t['elo_max'] as num?)?.toDouble() ?? 10.0;
    final maxPlayers = t['max_players'] as int? ?? 0;
    final multiplier = (t['elo_multiplier'] as num?)?.toDouble() ?? 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            const Divider(height: 24),
            _InfoRow(
                icon: Icons.format_list_bulleted,
                label: l.tournamentDetailFormatLabel,
                value: format == 'single_elimination'
                    ? l.tournamentFormatSingleElim
                    : l.tournamentFormatRoundRobin),
            _InfoRow(
                icon: Icons.calendar_today,
                label: l.tournamentDetailStartsLabel,
                value: startsAt),
            _InfoRow(
                icon: Icons.event_available,
                label: l.tournamentDetailEndsLabel,
                value: endsAt),
            _InfoRow(
                icon: Icons.people_outline,
                label: l.tournamentDetailMaxPlayersLabel,
                value: '$maxPlayers'),
            _InfoRow(
                icon: Icons.trending_up,
                label: l.tournamentDetailEloRangeLabel,
                value:
                    '${eloMin.toStringAsFixed(1)} – ${eloMax.toStringAsFixed(1)}'),
            _InfoRow(
                icon: Icons.star_outline,
                label: l.tournamentDetailMultiplierLabel,
                value: '×${multiplier.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.outline)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Registration CTA ─────────────────────────────────────────────────────────

class _RegistrationCta extends StatelessWidget {
  const _RegistrationCta({
    required this.t,
    required this.tournamentId,
    required this.profileAsync,
    required this.ref,
  });

  final Map<String, dynamic> t;
  final String tournamentId;
  final AsyncValue profileAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isOpen = t['registration_open'] as bool? ?? false;
    final status = t['status'] as String? ?? '';
    if (!isOpen || status != 'registration_open') return const SizedBox.shrink();

    final actionState = ref.watch(tournamentActionsProvider);
    final isLoading = actionState is AsyncLoading;

    return FilledButton.icon(
      onPressed: isLoading
          ? null
          : () async {
              await ref
                  .read(tournamentActionsProvider.notifier)
                  .registerForTournament(tournamentId);
              if (!context.mounted) return;
              final st = ref.read(tournamentActionsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(st is AsyncError
                      ? st.error.toString()
                      : l.tournamentDetailRegisterSuccess),
                ),
              );
            },
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.how_to_reg_outlined),
      label: Text(l.actionRegister),
    );
  }
}

// ── Participant tile ──────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final player = r['player'] as Map?;
    final name = player?['display_name'] as String? ?? '—';
    final elo = (player?['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final tierStr = player?['elo_tier'] as String? ?? '5.0';
    final tier = EloTier.fromString(tierStr);
    final seed = r['seed'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: seed != null
            ? CircleAvatar(
                child: Text('$seed',
                    style: const TextStyle(fontWeight: FontWeight.bold)))
            : CircleAvatar(child: Text(name[0])),
        title: Text(name),
        subtitle: TierBadge(tier: tier, small: true),
        trailing: Text(elo.toStringAsFixed(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
      ),
    );
  }
}
