import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/tournament_bracket_viewer.dart';

/// SCR-12 — Organiser dashboard: tabbed list of own tournaments + create.
class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.organizerTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.organizerTabOpen),
              Tab(text: l.organizerTabInProgress),
              Tab(text: l.organizerTabCompleted),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TournamentList(statusFilter: 'registration_open'),
            _TournamentList(statusFilter: 'in_progress'),
            _TournamentList(statusFilter: 'completed'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateSheet(context, ref),
          icon: const Icon(Icons.add),
          label: Text(l.organizerCreateTitle),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateTournamentSheet(),
    );
  }
}

// ── Tournament list tab ───────────────────────────────────────────────────────

class _TournamentList extends ConsumerWidget {
  const _TournamentList({required this.statusFilter});
  final String statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(myTournamentsProvider(statusFilter: statusFilter));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(l.organizerNoTournaments,
                style: TextStyle(color: AppColors.outline)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(myTournamentsProvider(statusFilter: statusFilter)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _TournamentCard(t: list[i]),
          ),
        );
      },
    );
  }
}

// ── Tournament card ───────────────────────────────────────────────────────────

class _TournamentCard extends ConsumerWidget {
  const _TournamentCard({required this.t});
  final Map<String, dynamic> t;

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final id = t['id'] as String;
    final name = t['name'] as String? ?? '—';
    final status = t['status'] as String? ?? '';
    final format = t['format'] as String? ?? '';
    final startsAt = _formatDate(t['starts_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${format == 'single_elimination' ? l.tournamentFormatSingleElim : l.tournamentFormatRoundRobin}  ·  $startsAt',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.outline),
        ),
        children: [
          // Status controls
          _StatusControls(tournamentId: id, status: status),

          // Registrations
          _RegistrationsSection(tournamentId: id),

          // Bracket (in-progress / completed only)
          if (status == 'in_progress' || status == 'completed') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.organizerBracketSection,
                    style: Theme.of(context).textTheme.labelMedium),
              ),
            ),
            SizedBox(
              height: 320,
              child: TournamentBracketViewer(
                  tournamentId: id, isOrganizer: true),
            ),
          ],

          // "Full detail" link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/tournaments/$id'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l.organizerManage),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status lifecycle controls ─────────────────────────────────────────────────

class _StatusControls extends ConsumerWidget {
  const _StatusControls({required this.tournamentId, required this.status});
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
      final st = ref.read(tournamentActionsProvider);
      if (st is AsyncError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(st.error.toString())));
      }
    }

    Future<void> generateBracket() async {
      await ref
          .read(tournamentActionsProvider.notifier)
          .generateBracket(tournamentId);
      if (!context.mounted) return;
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(bracketMatchesProvider(tournamentId));
      final st = ref.read(tournamentActionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(st is AsyncError
            ? st.error.toString()
            : l.organizerGenerateBracketSuccess),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (status == 'draft')
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => transition('registration_open'),
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: Text(l.organizerOpenRegistration),
            ),
          if (status == 'registration_open')
            FilledButton.icon(
              onPressed: isLoading ? null : generateBracket,
              icon: isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_tree_outlined, size: 16),
              label: Text(l.organizerGenerateBracket),
            ),
          if (status == 'in_progress')
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => transition('completed'),
              icon: const Icon(Icons.emoji_events_outlined, size: 16),
              label: Text(l.organizerCompleteTourn),
            ),
        ],
      ),
    );
  }
}

// ── Registrations section ─────────────────────────────────────────────────────

class _RegistrationsSection extends ConsumerWidget {
  const _RegistrationsSection({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final regsAsync =
        ref.watch(tournamentRegistrationsProvider(tournamentId));

    return regsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
      data: (regs) => regs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l.organizerNoRegistrations,
                  style: TextStyle(color: AppColors.outline)),
            )
          : Column(
              children: regs
                  .map((r) => _RegistrationTile(r: r))
                  .toList(),
            ),
    );
  }
}

class _RegistrationTile extends ConsumerWidget {
  const _RegistrationTile({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = r['player'] as Map?;
    final name = player?['display_name'] as String? ?? '—';
    final status = r['status'] as String? ?? '';

    return ListTile(
      title: Text(name),
      subtitle: Text(status),
      trailing: status == 'pending'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: AppColors.eloGain),
                  tooltip: 'Approve',
                  onPressed: () => ref
                      .read(tournamentActionsProvider.notifier)
                      .updateRegistrationStatus(r['id'] as String, 'approved'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.eloLoss),
                  tooltip: 'Reject',
                  onPressed: () => ref
                      .read(tournamentActionsProvider.notifier)
                      .updateRegistrationStatus(r['id'] as String, 'rejected'),
                ),
              ],
            )
          : null,
    );
  }
}

// ── Create tournament bottom sheet ────────────────────────────────────────────

class _CreateTournamentSheet extends ConsumerStatefulWidget {
  const _CreateTournamentSheet();

  @override
  ConsumerState<_CreateTournamentSheet> createState() =>
      _CreateTournamentSheetState();
}

class _CreateTournamentSheetState
    extends ConsumerState<_CreateTournamentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _format = 'single_elimination';
  double _eloMin = 5.0;
  double _eloMax = 10.0;
  int _maxPlayers = 16;
  double _multiplier = 1.0;
  DateTime? _startsAt;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final actionState = ref.watch(tournamentActionsProvider);
    final isLoading = actionState is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outline.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(l.organizerCreateTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: l.organizerNameLabel),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(labelText: l.organizerDescLabel),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _format,
                decoration: InputDecoration(labelText: l.organizerFormatLabel),
                items: [
                  DropdownMenuItem(
                      value: 'single_elimination',
                      child: Text(l.tournamentFormatSingleElim)),
                  DropdownMenuItem(
                      value: 'round_robin',
                      child: Text(l.tournamentFormatRoundRobin)),
                ],
                onChanged: (v) => setState(() => _format = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _eloMin.toStringAsFixed(1),
                      decoration:
                          InputDecoration(labelText: l.organizerEloMinLabel),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _eloMin = double.tryParse(v) ?? _eloMin,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _eloMax.toStringAsFixed(1),
                      decoration:
                          InputDecoration(labelText: l.organizerEloMaxLabel),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _eloMax = double.tryParse(v) ?? _eloMax,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_maxPlayers',
                      decoration:
                          InputDecoration(labelText: l.organizerMaxPlayersLabel),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _maxPlayers = int.tryParse(v) ?? _maxPlayers,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _multiplier.toStringAsFixed(1),
                      decoration:
                          InputDecoration(labelText: l.organizerMultiplierLabel),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _multiplier = double.tryParse(v) ?? _multiplier,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                        _startsAt == null
                            ? l.organizerPickStartDate
                            : '${_startsAt!.day}/${_startsAt!.month}/${_startsAt!.year}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _startsAt == null
                                  ? AppColors.outline
                                  : AppColors.onSurface,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l.organizerCreateButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startsAt = picked);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.errorPickStartDate)),
      );
      return;
    }
    await ref.read(tournamentActionsProvider.notifier).createTournament(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          format: _format,
          eloMin: _eloMin,
          eloMax: _eloMax,
          maxPlayers: _maxPlayers,
          startsAt: _startsAt!,
          eloMultiplier: _multiplier,
        );
    if (!mounted) return;
    final st = ref.read(tournamentActionsProvider);
    if (st is AsyncData) {
      ref.invalidate(myTournamentsProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.organizerCreateSuccess)),
      );
    } else if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.error.toString())),
      );
    }
  }
}
