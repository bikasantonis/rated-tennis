import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/tournament_bracket_viewer.dart';

/// SCR-13 — Per-tournament management screen for organisers.
///
/// Route: /organizer/tournaments/:id
/// Tabs: Registrations | Status Controls | Bracket
class OrganizerTournamentDetailScreen extends ConsumerWidget {
  const OrganizerTournamentDetailScreen({
    required this.tournamentId,
    super.key,
  });

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(tournamentDetailProvider(tournamentId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.organizerManageTournament)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l.organizerManageTournament)),
        body: Center(child: Text('Error: $e')),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.organizerManageTournament)),
            body: const Center(child: Text('Tournament not found.')),
          );
        }
        final name = detail['name'] as String? ?? '—';
        final status = detail['status'] as String? ?? '';

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.pop()),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name),
                  _StatusChip(status: status),
                ],
              ),
              bottom: TabBar(
                tabs: [
                  Tab(text: l.organizerTabRegistrations),
                  Tab(text: l.organizerTabStatusControls),
                  Tab(text: l.organizerBracketSection),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RegistrationsTab(tournamentId: tournamentId),
                _StatusControlsTab(tournamentId: tournamentId, status: status),
                _BracketTab(tournamentId: tournamentId, status: status),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'draft' => ('Draft', AppColors.outline),
      'registration_open' => ('Registration Open', AppColors.eloGain),
      'in_progress' => ('In Progress', AppColors.primary),
      'completed' => ('Completed', AppColors.eloLoss),
      _ => (status, AppColors.outline),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Registrations tab ─────────────────────────────────────────────────────────

class _RegistrationsTab extends ConsumerWidget {
  const _RegistrationsTab({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final regsAsync =
        ref.watch(allTournamentRegistrationsProvider(tournamentId));

    return regsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (regs) {
        if (regs.isEmpty) {
          return Center(
            child: Text(l.organizerNoRegistrations,
                style: TextStyle(color: AppColors.outline)),
          );
        }

        // Group by status for easier scanning
        final pending =
            regs.where((r) => r['status'] == 'pending').toList();
        final approved =
            regs.where((r) => r['status'] == 'approved').toList();
        final rejected =
            regs.where((r) => r['status'] == 'rejected').toList();

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(allTournamentRegistrationsProvider(tournamentId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    label: l.organizerRegStatusPending,
                    count: pending.length),
                ...pending.map((r) => _RegistrationTile(
                    r: r, tournamentId: tournamentId)),
                const SizedBox(height: 8),
              ],
              if (approved.isNotEmpty) ...[
                _SectionHeader(
                    label: l.organizerRegStatusApproved,
                    count: approved.length),
                ...approved.map((r) => _RegistrationTile(
                    r: r, tournamentId: tournamentId)),
                const SizedBox(height: 8),
              ],
              if (rejected.isNotEmpty) ...[
                _SectionHeader(
                    label: l.organizerRegStatusRejected,
                    count: rejected.length),
                ...rejected.map((r) => _RegistrationTile(
                    r: r, tournamentId: tournamentId)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.outline)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.outline.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(fontSize: 11, color: AppColors.outline)),
          ),
        ],
      ),
    );
  }
}

class _RegistrationTile extends ConsumerWidget {
  const _RegistrationTile(
      {required this.r, required this.tournamentId});
  final Map<String, dynamic> r;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = r['player'] as Map?;
    final name = player?['display_name'] as String? ?? '—';
    final elo = player?['elo_rating'];
    final status = r['status'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withAlpha(30),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name),
        subtitle: elo != null
            ? Text('ELO ${(elo as num).toStringAsFixed(1)}',
                style: TextStyle(
                    color: AppColors.outline, fontSize: 12))
            : null,
        trailing: status == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: AppColors.eloGain),
                    tooltip: 'Approve',
                    onPressed: () async {
                      await ref
                          .read(tournamentActionsProvider.notifier)
                          .updateRegistrationStatus(
                              r['id'] as String, 'approved');
                      ref.invalidate(
                          allTournamentRegistrationsProvider(tournamentId));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppColors.eloLoss),
                    tooltip: 'Reject',
                    onPressed: () async {
                      await ref
                          .read(tournamentActionsProvider.notifier)
                          .updateRegistrationStatus(
                              r['id'] as String, 'rejected');
                      ref.invalidate(
                          allTournamentRegistrationsProvider(tournamentId));
                    },
                  ),
                ],
              )
            : Icon(
                status == 'approved'
                    ? Icons.check_circle
                    : Icons.cancel,
                color: status == 'approved'
                    ? AppColors.eloGain
                    : AppColors.eloLoss,
                size: 20,
              ),
      ),
    );
  }
}

// ── Status controls tab ───────────────────────────────────────────────────────

class _StatusControlsTab extends ConsumerWidget {
  const _StatusControlsTab(
      {required this.tournamentId, required this.status});
  final String tournamentId;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final actionState = ref.watch(tournamentActionsProvider);
    final isLoading = actionState is AsyncLoading;

    Future<void> transition(String newStatus) async {
      await ref
          .read(tournamentActionsProvider.notifier)
          .updateTournamentStatus(tournamentId, newStatus);
      if (!context.mounted) return;
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(tournamentDetailProvider(tournamentId));
      final st = ref.read(tournamentActionsProvider);
      if (st is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(st.error.toString())));
      }
    }

    Future<void> generateBracket() async {
      await ref
          .read(tournamentActionsProvider.notifier)
          .generateBracket(tournamentId);
      if (!context.mounted) return;
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(tournamentDetailProvider(tournamentId));
      ref.invalidate(bracketMatchesProvider(tournamentId));
      final st = ref.read(tournamentActionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(st is AsyncError
            ? st.error.toString()
            : l.organizerGenerateBracketSuccess),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Lifecycle stepper
        _LifecycleStepper(currentStatus: status),
        const SizedBox(height: 32),

        // Action buttons
        if (status == 'draft')
          _ActionCard(
            icon: Icons.how_to_reg_outlined,
            title: l.organizerOpenRegistration,
            description: l.organizerOpenRegistrationDesc,
            buttonLabel: l.organizerOpenRegistration,
            isLoading: isLoading,
            onTap: () => transition('registration_open'),
          ),

        if (status == 'registration_open')
          _ActionCard(
            icon: Icons.account_tree_outlined,
            title: l.organizerGenerateBracket,
            description: l.organizerGenerateBracketDesc,
            buttonLabel: l.organizerGenerateBracket,
            isLoading: isLoading,
            isPrimary: true,
            onTap: generateBracket,
          ),

        if (status == 'in_progress')
          _ActionCard(
            icon: Icons.emoji_events_outlined,
            title: l.organizerCompleteTourn,
            description: l.organizerCompleteTournDesc,
            buttonLabel: l.organizerCompleteTourn,
            isLoading: isLoading,
            onTap: () => transition('completed'),
          ),

        if (status == 'completed')
          Center(
            child: Column(
              children: [
                const Icon(Icons.emoji_events,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(l.organizerTournamentCompleted,
                    style:
                        Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.currentStatus});
  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('draft', 'Draft'),
      ('registration_open', 'Open'),
      ('in_progress', 'In Progress'),
      ('completed', 'Done'),
    ];
    final currentIndex =
        steps.indexWhere((s) => s.$1 == currentStatus);

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepDot(
            label: steps[i].$2,
            isDone: i < currentIndex,
            isCurrent: i == currentIndex,
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentIndex
                    ? AppColors.primary
                    : AppColors.outline.withAlpha(60),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.label,
      required this.isDone,
      required this.isCurrent});
  final String label;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isDone || isCurrent ? AppColors.primary : AppColors.outline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.primary
                : isCurrent
                    ? AppColors.primary.withAlpha(30)
                    : AppColors.outline.withAlpha(30),
            border: Border.all(
                color: color,
                width: isCurrent ? 2 : 1),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight:
                    isCurrent ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isLoading,
    required this.onTap,
    this.isPrimary = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool isLoading;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.outline)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isPrimary
                  ? FilledButton.icon(
                      onPressed: isLoading ? null : onTap,
                      icon: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(icon, size: 16),
                      label: Text(buttonLabel),
                    )
                  : OutlinedButton.icon(
                      onPressed: isLoading ? null : onTap,
                      icon: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Icon(icon, size: 16),
                      label: Text(buttonLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bracket tab ───────────────────────────────────────────────────────────────

class _BracketTab extends StatelessWidget {
  const _BracketTab({required this.tournamentId, required this.status});
  final String tournamentId;
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (status == 'draft' || status == 'registration_open') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(l.organizerBracketNotGeneratedYet,
                style:
                    TextStyle(color: AppColors.outline)),
          ],
        ),
      );
    }
    return TournamentBracketViewer(
        tournamentId: tournamentId, isOrganizer: true);
  }
}
