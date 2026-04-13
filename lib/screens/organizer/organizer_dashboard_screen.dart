import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/providers/tournament_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/pending_badge.dart';

/// SCR-12 — Organiser dashboard: tabbed list of own tournaments + create.
class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    final openCount = ref
            .watch(myTournamentsProvider(statusFilter: 'registration_open'))
            .asData
            ?.value
            .length ??
        0;
    final inProgressCount = ref
            .watch(myTournamentsProvider(statusFilter: 'in_progress'))
            .asData
            ?.value
            .length ??
        0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.organizerTitle),
          bottom: TabBar(
            tabs: [
              TabWithBadge(label: l.organizerTabOpen, count: openCount),
              TabWithBadge(
                  label: l.organizerTabInProgress, count: inProgressCount),
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

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.t});
  final Map<String, dynamic> t;

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  Color _statusColor(String status) => switch (status) {
        'draft' => AppColors.outline,
        'registration_open' => AppColors.eloGain,
        'in_progress' => AppColors.primary,
        'completed' => AppColors.eloLoss,
        _ => AppColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final id = t['id'] as String;
    final name = t['name'] as String? ?? '—';
    final status = t['status'] as String? ?? '';
    final format = t['format'] as String? ?? '';
    final startsAt = _formatDate(t['starts_at']);
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/organizer/tournaments/$id'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${format == 'single_elimination' ? l.tournamentFormatSingleElim : l.tournamentFormatRoundRobin}  ·  $startsAt',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
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
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  String _format = 'single_elimination';
  double _eloMin = 5.0;
  double _eloMax = 10.0;
  int _maxPlayers = 16;
  double _multiplier = 1.0;
  DateTime? _startsAt;
  double? _venueLat;
  double? _venueLng;
  bool _locationSet = false;
  bool _fetchingLocation = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
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
                initialValue: _format,
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
              const SizedBox(height: 12),
              // ── Venue location (optional) ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(labelText: l.organizerCityLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _countryCtrl,
                      decoration: InputDecoration(labelText: l.organizerCountryLabel),
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading || _fetchingLocation ? null : _useMyLocation,
                icon: _fetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _locationSet ? Icons.check_circle : Icons.my_location,
                        color: _locationSet ? AppColors.eloGain : null,
                      ),
                label: Text(_locationSet
                    ? l.organizerLocationSet
                    : l.organizerUseMyLocation),
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

  Future<void> _useMyLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Round to 2 dp for data minimisation
      setState(() {
        _venueLat = (position.latitude * 100).roundToDouble() / 100;
        _venueLng = (position.longitude * 100).roundToDouble() / 100;
        _locationSet = true;
        _fetchingLocation = false;
      });
    } catch (_) {
      setState(() => _fetchingLocation = false);
    }
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
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          country: _countryCtrl.text.trim().isEmpty
              ? null
              : _countryCtrl.text.trim().toUpperCase(),
          venueLat: _venueLat,
          venueLng: _venueLng,
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
