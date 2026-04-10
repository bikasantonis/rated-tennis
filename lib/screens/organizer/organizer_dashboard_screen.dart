import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// SCR-12 — Organizer dashboard: create tournament, manage registrations.
class OrganizerDashboardScreen extends ConsumerStatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  ConsumerState<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState
    extends ConsumerState<OrganizerDashboardScreen> {
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
    final myTournamentsAsync =
        ref.watch(tournamentsProvider(statusFilter: null));

    return Scaffold(
      appBar: AppBar(title: Text(l.organizerTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Create tournament ────────────────────────────────────────
            Text(l.organizerCreateTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration:
                            InputDecoration(labelText: l.organizerNameLabel),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: InputDecoration(
                            labelText: l.organizerDescLabel),
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
                              decoration: InputDecoration(
                                  labelText: l.organizerMaxPlayersLabel),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  _maxPlayers = int.tryParse(v) ?? _maxPlayers,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: _multiplier.toStringAsFixed(1),
                              decoration: InputDecoration(
                                  labelText: l.organizerMultiplierLabel),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  _multiplier =
                                      double.tryParse(v) ?? _multiplier,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: _startsAt == null
                                          ? AppColors.outline
                                          : AppColors.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
            ),
            const SizedBox(height: 24),

            // ── My tournaments ───────────────────────────────────────────
            Text(l.organizerMyTournaments,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            myTournamentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (list) => list.isEmpty
                  ? Text(l.organizerNoTournaments,
                      style: TextStyle(color: AppColors.outline))
                  : Column(
                      children: list
                          .map((t) => _MyTournamentTile(t: t, ref: ref))
                          .toList(),
                    ),
            ),
          ],
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
      ref.invalidate(tournamentsProvider);
      _nameCtrl.clear();
      _descCtrl.clear();
      setState(() => _startsAt = null);
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

class _MyTournamentTile extends StatelessWidget {
  const _MyTournamentTile({required this.t, required this.ref});
  final Map<String, dynamic> t;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = t['name'] as String? ?? '—';
    final status = t['status'] as String? ?? '';
    final regsAsync =
        ref.watch(tournamentRegistrationsProvider(t['id'] as String));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(name),
        subtitle: Text(status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.primary)),
        children: [
          regsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
            data: (regs) => regs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.organizerNoRegistrations),
                  )
                : Column(
                    children: regs
                        .map((r) => _RegistrationTile(r: r, ref: ref))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.r, required this.ref});
  final Map<String, dynamic> r;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
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
                      .updateRegistrationStatus(
                          r['id'] as String, 'approved'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.eloLoss),
                  tooltip: 'Reject',
                  onPressed: () => ref
                      .read(tournamentActionsProvider.notifier)
                      .updateRegistrationStatus(
                          r['id'] as String, 'rejected'),
                ),
              ],
            )
          : null,
    );
  }
}
