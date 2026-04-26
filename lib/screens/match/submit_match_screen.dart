import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/models/match_result.dart';
import 'package:rated/models/match_validation.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/theme/app_colors.dart';

// ── Local aliases (keep screen code readable) ─────────────────────────────────

typedef _FormatConfig = MatchFormatConfig;
typedef _SetType = MatchSetType;

_FormatConfig _configFor(MatchFormat f) => matchFormatConfig(f);
bool _isValidSet(int w, int l, _SetType t) => isValidSet(w, l, t);

// ── Validation errors (screen-private wrappers for l10n mapping) ──────────────

String _errorText(MatchValidationError err, AppLocalizations l) =>
    switch (err) {
      InvalidSet(:final setNumber) => l.scoreInvalidSet(setNumber),
      MatchIncomplete() => l.scoreMatchIncomplete,
      WinnerMustWin(:final setsNeeded) => l.scoreWinnerMustWin(setsNeeded),
      ExtraSets() => l.scoreExtraSets,
    };

// ── Match-level validation (delegates to match_validation.dart) ───────────────

/// Validates all sets against [format] rules.
/// Returns null when the match is fully valid.
MatchValidationError? _validateMatch(
  List<_SetEntry> sets,
  MatchFormat format,
  bool currentUserWon,
) {
  final pairs = <SetPair>[];
  for (final s in sets) {
    final w = int.tryParse(s.winnerCtrl.text);
    final l = int.tryParse(s.loserCtrl.text);
    if (w == null || l == null || w < 0 || l < 0) {
      return InvalidSet(sets.indexOf(s) + 1);
    }
    pairs.add((winner: w, loser: l));
  }
  return validateMatch(pairs, format);
}

/// Returns true when the "Add Set" button should be shown.
bool _canAddSet(List<_SetEntry> sets, _FormatConfig config) {
  if (sets.length >= config.maxSets) return false;
  int wWins = 0, lWins = 0;
  for (int i = 0; i < sets.length; i++) {
    final w = int.tryParse(sets[i].winnerCtrl.text);
    final l = int.tryParse(sets[i].loserCtrl.text);
    if (w == null || l == null || w < 0 || l < 0) return true;
    if (i < config.setTypes.length && _isValidSet(w, l, config.setTypes[i])) {
      if (w > l) {
        wWins++;
      } else {
        lWins++;
      }
      if (wWins >= config.setsToWin || lWins >= config.setsToWin) return false;
    }
  }
  return true;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// SCR-07 — Submit a friendly match result.
/// Steps: opponent → format → outcome → score → date → submit.
class SubmitMatchScreen extends ConsumerStatefulWidget {
  const SubmitMatchScreen({super.key});

  @override
  ConsumerState<SubmitMatchScreen> createState() => _SubmitMatchScreenState();
}

class _SubmitMatchScreenState extends ConsumerState<SubmitMatchScreen> {
  final _searchController = TextEditingController();

  int _step = 0;
  Map<String, dynamic>? _opponent;
  MatchFormat _format = MatchFormat.bo3SuperTb; // default per product spec
  bool? _currentUserWon;
  final List<_SetEntry> _sets = [_SetEntry()];
  DateTime _playedAt = DateTime.now();

  bool get _canAdvance => switch (_step) {
        0 => _opponent != null,
        1 => true, // format always has a valid selection
        2 => _currentUserWon != null,
        3 => _sets.isNotEmpty &&
            _sets.every((s) => s.isParseable) &&
            _validateMatch(_sets, _format, _currentUserWon!) == null,
        4 => true,
        _ => false,
      };

  void _advance() => setState(() => _step++);
  void _back() => setState(() => _step--);

  void _onFormatChanged(MatchFormat f) {
    if (f == _format) return;
    setState(() {
      _format = f;
      // Reset score entries — they may be invalid for the new format.
      for (final s in _sets) {
        s.dispose();
      }
      _sets
        ..clear()
        ..add(_SetEntry());
    });
  }

  Future<void> _submit() async {
    await ref.read(matchActionsProvider.notifier).submitMatch(
          opponentId: _opponent!['id'] as String,
          currentUserWon: _currentUserWon!,
          sets: _sets.map((s) => s.toSetScore(_currentUserWon!)).toList(),
          playedAt: _playedAt,
          format: _format,
        );

    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final st = ref.read(matchActionsProvider);
    if (st is AsyncData) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.submitMatchSuccess)));
      context.pop();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final s in _sets) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final actionState = ref.watch(matchActionsProvider);
    final isLoading = actionState is AsyncLoading;

    final eloExcluded = _opponent != null
        ? ref.watch(
            friendlyEloExcludedProvider(_opponent!['id'] as String),
          )
        : const AsyncData<bool>(false);
    final showEloBanner = eloExcluded.asData?.value == true;

    ref.listen(matchActionsProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    // Match error is only computed once all sets are parseable and outcome chosen.
    final bool allParseable = _sets.every((s) => s.isParseable);
    final MatchValidationError? matchError =
        (allParseable && _currentUserWon != null)
            ? _validateMatch(_sets, _format, _currentUserWon!)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.submitMatchTitle),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isLoading ? null : _back,
              )
            : null,
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, total: 5),
          if (showEloBanner)
            _EloExcludedBanner(message: l.submitMatchEloExcludedBanner),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: switch (_step) {
                0 => _OpponentStep(
                    controller: _searchController,
                    selected: _opponent,
                    onSelected: (p) => setState(() => _opponent = p),
                  ),
                1 => _FormatStep(
                    selected: _format,
                    onChanged: _onFormatChanged,
                  ),
                2 => _OutcomeStep(
                    opponentName: _opponent!['display_name'] as String,
                    selected: _currentUserWon,
                    onSelected: (v) => setState(() => _currentUserWon = v),
                  ),
                3 => _ScoreStep(
                    sets: _sets,
                    format: _format,
                    currentUserWon: _currentUserWon!,
                    opponentName: _opponent!['display_name'] as String,
                    matchError: matchError,
                    onAddSet: () => setState(() => _sets.add(_SetEntry())),
                    onRemoveSet: (i) => setState(() => _sets.removeAt(i)),
                    onChanged: () => setState(() {}),
                  ),
                4 => _DateStep(
                    selected: _playedAt,
                    onChanged: (d) => setState(() => _playedAt = d),
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_canAdvance && !isLoading)
                    ? (_step == 4 ? _submit : _advance)
                    : null,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_step == 4 ? l.submitMatchSubmit : l.actionNext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ELO-excluded info banner ──────────────────────────────────────────────────

class _EloExcludedBanner extends StatelessWidget {
  const _EloExcludedBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.tertiary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (current + 1) / total,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${current + 1} of $total',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Step 0: Opponent search ───────────────────────────────────────────────────

class _OpponentStep extends ConsumerWidget {
  const _OpponentStep({
    required this.controller,
    required this.selected,
    required this.onSelected,
  });
  final TextEditingController controller;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final query = controller.text;
    final searchAsync = ref.watch(searchOpponentsProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.submitMatchSearchOpponent,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          onChanged: (_) => ref.invalidate(searchOpponentsProvider),
          decoration: InputDecoration(
            hintText: l.submitMatchSearchOpponent,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        if (selected != null) ...[
          _PlayerTile(player: selected!, selected: true, onTap: () {}),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
        ],
        if (query.trim().length >= 2)
          searchAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${l.errorSearchFailed}: $e'),
            data: (results) => results.isEmpty
                ? Text(l.submitMatchNoResults)
                : Column(
                    children: results
                        .map((p) => _PlayerTile(
                              player: p,
                              selected: selected?['id'] == p['id'],
                              onTap: () => onSelected(p),
                            ))
                        .toList(),
                  ),
          ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.selected,
    required this.onTap,
  });
  final Map<String, dynamic> player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final elo = (player['elo_rating'] as num?)?.toDouble() ?? 5.0;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text((player['display_name'] as String)[0])),
      title: Text(player['display_name'] as String),
      subtitle: Text(l.eloLabel(elo.toStringAsFixed(1))),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      tileColor: selected ? AppColors.primaryContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ── Step 1: Format selection ──────────────────────────────────────────────────

class _FormatStep extends StatelessWidget {
  const _FormatStep({required this.selected, required this.onChanged});
  final MatchFormat selected;
  final ValueChanged<MatchFormat> onChanged;

  String _label(MatchFormat f, AppLocalizations l) => switch (f) {
        MatchFormat.bo3Standard => l.submitMatchFormatBo3Standard,
        MatchFormat.bo3SuperTb => l.submitMatchFormatBo3SuperTb,
        MatchFormat.bo3Mini3rd => l.submitMatchFormatBo3Mini3rd,
        MatchFormat.bo3MiniSuper => l.submitMatchFormatBo3MiniSuper,
        MatchFormat.oneFullSet => l.submitMatchFormatOneFullSet,
        MatchFormat.oneMiniSet => l.submitMatchFormatOneMiniSet,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.submitMatchFormatTitle,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        ...MatchFormat.values.map(
          (f) => _FormatTile(
            label: _label(f, l),
            selected: selected == f,
            onTap: () => onChanged(f),
          ),
        ),
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
            color: selected ? AppColors.primaryContainer : AppColors.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Outcome ───────────────────────────────────────────────────────────

class _OutcomeStep extends StatelessWidget {
  const _OutcomeStep({
    required this.opponentName,
    required this.selected,
    required this.onSelected,
  });
  final String opponentName;
  final bool? selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.submitMatchTitle,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _OutcomeTile(
          label: l.submitMatchOutcomeWon,
          icon: Icons.emoji_events,
          iconColor: AppColors.tier85Color,
          selected: selected == true,
          onTap: () => onSelected(true),
        ),
        const SizedBox(height: 10),
        _OutcomeTile(
          label: l.submitMatchOutcomeLost,
          icon: Icons.sentiment_dissatisfied,
          iconColor: AppColors.tertiary,
          selected: selected == false,
          onTap: () => onSelected(false),
        ),
      ],
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.primaryContainer : AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? AppColors.primary : AppColors.onSurface,
                    ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Score entry ───────────────────────────────────────────────────────

class _ScoreStep extends StatelessWidget {
  const _ScoreStep({
    required this.sets,
    required this.format,
    required this.currentUserWon,
    required this.opponentName,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onChanged,
    this.matchError,
  });
  final List<_SetEntry> sets;
  final MatchFormat format;
  final bool currentUserWon;
  final String opponentName;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;
  final VoidCallback onChanged;
  final MatchValidationError? matchError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final config = _configFor(format);
    final myLabel = 'You';
    final oppLabel = opponentName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.submitMatchScoreTitle,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        // Column headers
        Row(
          children: [
            const SizedBox(width: 56),
            Expanded(
              child: Center(
                child: Text(
                  currentUserWon ? myLabel : oppLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: Text(
                  currentUserWon ? oppLabel : myLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        ...sets.asMap().entries.map(
              (e) => _SetRow(
                index: e.key,
                entry: e.value,
                setType: e.key < config.setTypes.length
                    ? config.setTypes[e.key]
                    : _SetType.full,
                canRemove: sets.length > 1,
                onRemove: () => onRemoveSet(e.key),
                onChanged: onChanged,
              ),
            ),
        // Inline validation error
        if (matchError != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorText(matchError!, l),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.error),
          ),
        ],
        if (_canAddSet(sets, config))
          TextButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add),
            label: Text(l.submitMatchAddSet),
          ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.entry,
    required this.setType,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });
  final int index;
  final _SetEntry entry;
  final _SetType setType;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isSuperTb = setType == _SetType.superTiebreak;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: isSuperTb
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.submitMatchSet(index + 1),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        'TB',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  )
                : Text(
                    l.submitMatchSet(index + 1),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
          ),
          Expanded(
            child: _ScoreField(
              controller: entry.winnerCtrl,
              onChanged: (_) => onChanged(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _ScoreField(
              controller: entry.loserCtrl,
              onChanged: (_) => onChanged(),
            ),
          ),
          SizedBox(
            width: 40,
            child: canRemove
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: '0',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ── Step 4: Date ──────────────────────────────────────────────────────────────

class _DateStep extends StatelessWidget {
  const _DateStep({required this.selected, required this.onChanged});
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.submitMatchDateLabel,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(
            '${selected.day}/${selected.month}/${selected.year}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l.actionChange),
          tileColor: AppColors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now(),
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }
}

// ── Set entry helper ──────────────────────────────────────────────────────────

class _SetEntry {
  final winnerCtrl = TextEditingController();
  final loserCtrl = TextEditingController();

  /// True when both fields contain a non-negative integer.
  /// Full tennis-rule validation is done separately by [_validateMatch].
  bool get isParseable {
    final w = int.tryParse(winnerCtrl.text);
    final l = int.tryParse(loserCtrl.text);
    return w != null && l != null && w >= 0 && l >= 0;
  }

  /// Converts to [SetScore] using the match winner's perspective.
  /// [winnerCtrl] always holds the match winner's per-set score.
  SetScore toSetScore(bool currentUserWon) {
    final myScore = int.parse(winnerCtrl.text);
    final oppScore = int.parse(loserCtrl.text);
    return SetScore(
      winner: currentUserWon ? myScore : oppScore,
      loser: currentUserWon ? oppScore : myScore,
    );
  }

  void dispose() {
    winnerCtrl.dispose();
    loserCtrl.dispose();
  }
}
