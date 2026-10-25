import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/questionnaire_provider.dart';
import 'package:rated/screens/questionnaire/questionnaire_flow.dart';
import 'package:rated/theme/app_colors.dart';

/// Opens the questionnaire as a full-screen dialog.
/// Returns the [SeedResult] when the user completes it, null if dismissed.
Future<SeedResult?> showQuestionnaireDialog(BuildContext context) =>
    showDialog<SeedResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QuestionnaireDialog(),
    );

// ── Dialog ────────────────────────────────────────────────────────────────────

class QuestionnaireDialog extends ConsumerStatefulWidget {
  const QuestionnaireDialog({super.key});

  @override
  ConsumerState<QuestionnaireDialog> createState() =>
      _QuestionnaireDialogState();
}

class _QuestionnaireDialogState extends ConsumerState<QuestionnaireDialog> {
  /// All answers live in one bag; the routing rules that read it are pure and
  /// unit-tested in `questionnaire_flow.dart`.
  final _a = QuestionnaireAnswers();

  /// Index into [_steps] — never a fixed page number. The step list is derived
  /// from the answers, so a branch can appear or disappear without any index
  /// arithmetic elsewhere in this file.
  int _index = 0;

  final _yearsController = TextEditingController();
  final _rankingController = TextEditingController();
  final _tournamentsController = TextEditingController();

  List<QStep> get _steps => activeSteps(_a);
  QStep get _current => _steps[_index];
  bool get _currentAnswered => isStepValid(_current, _a);
  bool get _isLastStep => _index == _steps.length - 1;

  /// The single mutation path. Prunes answers that the new routing has made
  /// unreachable, then keeps [_index] inside the recomputed list.
  void _answer(VoidCallback mutate) {
    setState(() {
      mutate();
      pruneInactive(_a);
      if (_a.juniorCareerHighRanking == null) _rankingController.clear();
      if (_a.tournamentsPerYear == null) _tournamentsController.clear();
      final last = _steps.length - 1;
      if (_index > last) _index = last;
    });
  }

  void _next() {
    if (!_currentAnswered) return;
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _index++);
    }
  }

  void _back() => setState(() => _index = (_index - 1).clamp(0, _steps.length - 1));

  Future<void> _submit() async {
    await ref.read(questionnaireActionsProvider.notifier).submit(_a);
    if (!mounted) return;
    final st = ref.read(questionnaireActionsProvider);
    if (st is AsyncData<SeedResult?> && st.value != null) {
      Navigator.of(context).pop(st.value);
    }
  }

  @override
  void dispose() {
    _yearsController.dispose();
    _rankingController.dispose();
    _tournamentsController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final qState = ref.watch(questionnaireActionsProvider);
    final isLoading = qState is AsyncLoading;
    final hasError = qState is AsyncError;
    final errorMessage = qState is AsyncError ? qState.error.toString() : null;

    final steps = _steps;
    final total = steps.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.questionnaireTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.actionExit,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // ── Steps ───────────────────────────────────────────────────────
              // An AnimatedSwitcher rather than a PageView: the step list is
              // variable-length, and a PageController has to be reconciled
              // against a list that can shrink underneath it.
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_current),
                    child: _buildStep(_current, l),
                  ),
                ),
              ),

              // ── Error ───────────────────────────────────────────────────────
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMessage ?? l.errorGeneric,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ── Navigation ─────────────────────────────────────────────────
              Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : _back,
                        child: Text(l.actionBack),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: (_currentAnswered && !isLoading) ? _next : null,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isLastStep
                                  ? l.questionnaireGetMyRating
                                  : l.actionNext,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Progress ────────────────────────────────────────────────────
              // A bar, not dots: the total varies from six to nine depending on
              // the answers, and a reflowing dot row reads worse than a label.
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / total,
                      minHeight: 6,
                      backgroundColor: AppColors.outline,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.questionnaireStepCounter(_index + 1, total),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(QStep step, AppLocalizations l) => switch (step) {
        QStep.dob => _DobStep(
            selected: _a.dateOfBirth,
            onChanged: (d) => _answer(() => _a.dateOfBirth = d),
          ),
        QStep.years => _NumberStep(
            question: l.questionnaireYearsTitle,
            controller: _yearsController,
            hintText: l.questionnaireYearsHint,
            suffixText: l.questionnaireYearsUnit,
            maxDigits: 2,
            onChanged: (v) => _answer(() => _a.yearsPlaying = v),
          ),
        QStep.frequency => _ChoiceStep(
            question: l.questionnaireFrequencyTitle,
            options: [
              _Option('rarely', l.questionnaireFrequencyRarely,
                  l.questionnaireFrequencyRarelySub),
              _Option('monthly', l.questionnaireFrequencyMonthly,
                  l.questionnaireFrequencyMonthlySub),
              _Option('weekly', l.questionnaireFrequencyWeekly,
                  l.questionnaireFrequencyWeeklySub),
              _Option('multiple_weekly', l.questionnaireFrequencyMultipleWeekly,
                  l.questionnaireFrequencyMultipleWeeklySub),
            ],
            selected: _a.playFrequency,
            onChanged: (v) => _answer(() => _a.playFrequency = v),
          ),
        QStep.greek => _ChoiceStep(
            question: l.questionnaireGreekTitle,
            options: [
              _Option('recreational', l.questionnaireGreekRecreational,
                  l.questionnaireGreekRecreationalSub),
              _Option('national_u200', l.questionnaireGreekNationalU200,
                  l.questionnaireGreekNationalU200Sub),
              _Option('national_20_200', l.questionnaireGreekNational20200,
                  l.questionnaireGreekNational20200Sub),
              _Option('national_top20', l.questionnaireGreekNationalTop20,
                  l.questionnaireGreekNationalTop20Sub),
            ],
            selected: _a.greekExperience,
            onChanged: (v) => _answer(() => _a.greekExperience = v),
          ),
        QStep.international => _InternationalStep(
            selected: _a.internationalExperience,
            rankingController: _rankingController,
            receivedAtpWtaPoint: _a.receivedAtpWtaPoint,
            usCollegeDivision: _a.usCollegeDivision,
            onExperienceChanged: (v) =>
                _answer(() => _a.internationalExperience = v),
            onRankingChanged: (v) =>
                _answer(() => _a.juniorCareerHighRanking = v),
            onAtpWtaChanged: (v) => _answer(() => _a.receivedAtpWtaPoint = v),
            onDivisionChanged: (v) => _answer(() => _a.usCollegeDivision = v),
          ),
        QStep.tournaments3y => _YesNoStep(
            question: l.questionnaireTournamentsTitle,
            subtitle: l.questionnaireTournamentsSub,
            yesLabel: l.actionYes,
            noLabel: l.actionNo,
            selected: _a.tournamentsLast3y,
            onChanged: (v) => _answer(() => _a.tournamentsLast3y = v),
          ),
        QStep.tournamentsPerYear => _NumberStep(
            question: l.questionnaireTournamentsPerYearTitle,
            controller: _tournamentsController,
            hintText: l.questionnaireTournamentsPerYearHint,
            suffixText: l.questionnaireTournamentsPerYearUnit,
            maxDigits: 3,
            onChanged: (v) => _answer(() => _a.tournamentsPerYear = v),
          ),
        QStep.tournamentLevel => _ChoiceStep(
            question: l.questionnaireTournamentLevelTitle,
            options: [
              _Option('amateur', l.questionnaireLevelAmateur,
                  l.questionnaireLevelAmateurSub),
              _Option('intermediate', l.questionnaireLevelIntermediate,
                  l.questionnaireLevelIntermediateSub),
              _Option('age_category', l.questionnaireLevelAgeCategory,
                  l.questionnaireLevelAgeCategorySub),
              _Option('master', l.questionnaireLevelMaster,
                  l.questionnaireLevelMasterSub),
              _Option('open', l.questionnaireLevelOpen,
                  l.questionnaireLevelOpenSub),
            ],
            selected: _a.tournamentLevel,
            onChanged: (v) => _answer(() => _a.tournamentLevel = v),
          ),
        QStep.otherSport => _ChoiceStep(
            question: l.questionnaireOtherSportTitle,
            options: [
              _Option('racket_sports', l.questionnaireOtherSportRacket,
                  l.questionnaireOtherSportRacketSub),
              _Option('other_sports', l.questionnaireOtherSportOther,
                  l.questionnaireOtherSportOtherSub),
              _Option('none', l.questionnaireOtherSportNone,
                  l.questionnaireOtherSportNoneSub),
            ],
            selected: _a.otherSport,
            onChanged: (v) => _answer(() => _a.otherSport = v),
          ),
      };
}

// ── Step: date of birth ───────────────────────────────────────────────────────

class _DobStep extends StatelessWidget {
  const _DobStep({required this.selected, required this.onChanged});
  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // The picker range mirrors the 16–90 gate in seed-elo, so an ineligible date
    // cannot be chosen at all rather than failing after the whole questionnaire.
    final now = DateTime.now();
    final latest = DateTime(now.year - kMinAge, now.month, now.day);
    final earliest = DateTime(now.year - kMaxAge, now.month, now.day);

    return _StepScaffoldCustom(
      question: l.questionnaireDobTitle,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selected ?? DateTime(1990),
            firstDate: earliest,
            lastDate: latest,
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected != null ? AppColors.primary : AppColors.outline,
              width: selected != null ? 2 : 1,
            ),
            color: selected != null
                ? AppColors.primaryContainer
                : AppColors.surface,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: selected != null
                    ? AppColors.primary
                    : AppColors.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected == null
                      ? l.questionnaireDobPlaceholder
                      : DateFormat('MMMM d, yyyy').format(selected!),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: selected != null
                            ? AppColors.primary
                            : AppColors.onSurface.withValues(alpha: 0.55),
                        fontWeight: selected != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                ),
              ),
              if (selected != null)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step: a bounded whole number ──────────────────────────────────────────────

class _NumberStep extends StatelessWidget {
  const _NumberStep({
    required this.question,
    required this.controller,
    required this.hintText,
    required this.suffixText,
    required this.maxDigits,
    required this.onChanged,
  });
  final String question;
  final TextEditingController controller;
  final String hintText;
  final String suffixText;
  final int maxDigits;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => _StepScaffoldCustom(
        question: question,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxDigits),
          ],
          decoration: InputDecoration(
            hintText: hintText,
            suffixText: suffixText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (v) => onChanged(int.tryParse(v)),
        ),
      );
}

// ── Step: yes / no ────────────────────────────────────────────────────────────

class _YesNoStep extends StatelessWidget {
  const _YesNoStep({
    required this.question,
    required this.subtitle,
    required this.yesLabel,
    required this.noLabel,
    required this.selected,
    required this.onChanged,
  });
  final String question;
  final String subtitle;
  final String yesLabel;
  final String noLabel;
  final bool? selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _StepScaffoldCustom(
        question: question,
        subtitle: subtitle,
        child: Column(
          children: [
            _OptionTile(
              label: yesLabel,
              subtitle: '',
              selected: selected == true,
              onTap: () => onChanged(true),
            ),
            _OptionTile(
              label: noLabel,
              subtitle: '',
              selected: selected == false,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      );
}

// ── Step: international experience (with inline sub-questions) ───────────────

class _InternationalStep extends StatelessWidget {
  const _InternationalStep({
    required this.selected,
    required this.rankingController,
    required this.receivedAtpWtaPoint,
    required this.usCollegeDivision,
    required this.onExperienceChanged,
    required this.onRankingChanged,
    required this.onAtpWtaChanged,
    required this.onDivisionChanged,
  });

  final String? selected;
  final TextEditingController rankingController;
  final bool? receivedAtpWtaPoint;
  final String? usCollegeDivision;
  final ValueChanged<String> onExperienceChanged;
  final ValueChanged<int?> onRankingChanged;
  final ValueChanged<bool> onAtpWtaChanged;
  final ValueChanged<String> onDivisionChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // (slug, label) pairs: the stored value is a slug, the label is localised.
    // v2 stored the rendered English string as the value, which made the UI copy
    // and the scoring key the same thing — migration 030 normalises those rows.
    final divisions = <(String, String)>[
      ('division_1', l.questionnaireDivision1),
      ('division_2', l.questionnaireDivision2),
      ('division_3', l.questionnaireDivision3),
      ('naia', l.questionnaireDivisionNaia),
      ('njcaa', l.questionnaireDivisionNjcaa),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.questionnaireIntlTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 16),

          _OptionTile(
            label: l.questionnaireIntlNone,
            subtitle: l.questionnaireIntlNoneSub,
            selected: selected == 'none',
            onTap: () => onExperienceChanged('none'),
          ),

          _OptionTile(
            label: l.questionnaireIntlRecreational,
            subtitle: l.questionnaireIntlRecreationalSub,
            selected: selected == 'recreational_intl',
            onTap: () => onExperienceChanged('recreational_intl'),
          ),

          _OptionTile(
            label: l.questionnaireIntlJunior,
            subtitle: l.questionnaireIntlJuniorSub,
            selected: selected == 'junior_intl',
            onTap: () => onExperienceChanged('junior_intl'),
          ),
          if (selected == 'junior_intl') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: TextField(
                controller: rankingController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l.questionnaireIntlCareerHighLabel,
                  hintText: l.questionnaireIntlCareerHighHint,
                  prefixText: '# ',
                  helperText: l.questionnaireIntlCareerHighHelper,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  onRankingChanged((n != null && n > 0) ? n : null);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          _OptionTile(
            label: l.questionnaireIntlProfessional,
            subtitle: l.questionnaireIntlProfessionalSub,
            selected: selected == 'professional_adult',
            onTap: () => onExperienceChanged('professional_adult'),
          ),
          if (selected == 'professional_adult') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.questionnaireIntlAtpWtaQuestion,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PillOption(
                        label: l.actionYes,
                        selected: receivedAtpWtaPoint == true,
                        onTap: () => onAtpWtaChanged(true),
                      ),
                      const SizedBox(width: 8),
                      _PillOption(
                        label: l.actionNo,
                        selected: receivedAtpWtaPoint == false,
                        onTap: () => onAtpWtaChanged(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          _OptionTile(
            label: l.questionnaireIntlCollege,
            subtitle: l.questionnaireIntlCollegeSub,
            selected: selected == 'us_college',
            onTap: () => onExperienceChanged('us_college'),
          ),
          if (selected == 'us_college') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.questionnaireIntlCollegeDivision,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: divisions
                        .map(
                          (d) => _PillOption(
                            label: d.$2,
                            selected: usCollegeDivision == d.$1,
                            onTap: () => onDivisionChanged(d.$1),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Reusable layout ───────────────────────────────────────────────────────────

class _Option {
  const _Option(this.value, this.label, this.subtitle);
  final String value;
  final String label;
  final String subtitle;
}

/// A question answered by picking one of a list of options. Serves every
/// single-choice step; only date-of-birth, the two numeric steps and the
/// international step (inline sub-questions) need bespoke layouts.
class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.question,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final String question;
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _StepScaffoldCustom(
        question: question,
        child: Column(
          children: options
              .map(
                (o) => _OptionTile(
                  label: o.label,
                  subtitle: o.subtitle,
                  selected: selected == o.value,
                  onTap: () => onChanged(o.value),
                ),
              )
              .toList(),
        ),
      );
}

class _StepScaffoldCustom extends StatelessWidget {
  const _StepScaffoldCustom({
    required this.question,
    required this.child,
    this.subtitle,
  });
  final String question;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 22),
              ],
            ),
          ),
        ),
      );
}

/// Small pill-shaped option for inline sub-questions (Yes/No, division, etc.)
class _PillOption extends StatelessWidget {
  const _PillOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
            color: selected ? AppColors.primaryContainer : AppColors.surface,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.onSurface,
                ),
          ),
        ),
      );
}
