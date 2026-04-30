import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/questionnaire_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// Opens the questionnaire as a full-screen dialog.
/// Returns true when the user completes it, false/null if dismissed.
Future<bool?> showQuestionnaireDialog(BuildContext context) =>
    showDialog<bool>(
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
  final _pageController = PageController();
  int _currentPage = 0;

  // Q1 — date of birth
  DateTime? _dateOfBirth;

  // Q2 — years playing
  int? _yearsPlaying;
  final _yearsController = TextEditingController();

  // Q3 — competitive experience in Greece
  // 'recreational' | 'national_u200' | 'national_20_200' | 'national_top20'
  String? _greekExperience;

  // Q4 — international experience + sub-fields
  // 'none' | 'recreational_intl' | 'junior_intl' | 'professional_adult' | 'us_college'
  String? _internationalExperience;
  int? _juniorCareerHighRanking;
  final _rankingController = TextEditingController();
  bool? _receivedAtpWtaPoint;
  String? _usCollegeDivision;

  // Q5 — other sport (only when Q3 == 'recreational')
  // 'racket_sports' | 'other_sports' | 'none'
  String? _otherSport;

  // ── Derived ─────────────────────────────────────────────────────────────────

  bool get _q5Active => _greekExperience == 'recreational';
  int get _totalPages => _q5Active ? 5 : 4;
  bool get _isLastPage => _currentPage == _totalPages - 1;

  bool get _q4Valid {
    switch (_internationalExperience) {
      case null:
        return false;
      case 'junior_intl':
        return _juniorCareerHighRanking != null;
      case 'professional_adult':
        return _receivedAtpWtaPoint != null;
      case 'us_college':
        return _usCollegeDivision != null;
      default:
        return true; // 'none' or 'recreational_intl'
    }
  }

  bool get _currentAnswered => switch (_currentPage) {
        0 => _dateOfBirth != null,
        1 => _yearsPlaying != null,
        2 => _greekExperience != null,
        3 => _q4Valid,
        4 => _otherSport != null,
        _ => false,
      };

  bool _isPageCompleted(int page) => switch (page) {
        0 => _dateOfBirth != null,
        1 => _yearsPlaying != null,
        2 => _greekExperience != null,
        3 => _q4Valid,
        4 => _otherSport != null,
        _ => false,
      };

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _next() {
    if (!_currentAnswered) return;
    if (_isLastPage) {
      _submit();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() => _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  Future<void> _submit() async {
    await ref.read(questionnaireActionsProvider.notifier).submit(
          dateOfBirth: _dateOfBirth!,
          yearsPlaying: _yearsPlaying!,
          greekExperience: _greekExperience!,
          internationalExperience: _internationalExperience!,
          juniorCareerHighRanking: _juniorCareerHighRanking,
          receivedAtpWtaPoint: _receivedAtpWtaPoint,
          usCollegeDivision: _usCollegeDivision,
          otherSport: _q5Active ? _otherSport : null,
        );
    if (!mounted) return;
    final st = ref.read(questionnaireActionsProvider);
    if (st is AsyncData) Navigator.of(context).pop(true);
  }

  // ── Greek experience change — reset Q5 if no longer applicable ───────────────

  void _onGreekChanged(String v) {
    setState(() {
      _greekExperience = v;
      _otherSport = null;
      // If the user was on page 4 (Q5) and it is now hidden, jump back.
      if (v != 'recreational' && _currentPage == 4) {
        _currentPage = 3;
        _pageController.jumpToPage(3);
      }
    });
  }

  // ── International experience change — reset sub-fields ───────────────────────

  void _onIntlChanged(String v) {
    setState(() {
      _internationalExperience = v;
      _juniorCareerHighRanking = null;
      _rankingController.clear();
      _receivedAtpWtaPoint = null;
      _usCollegeDivision = null;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _yearsController.dispose();
    _rankingController.dispose();
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    tooltip: 'Exit',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 16),

              // ── Pages ───────────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  children: [
                    _DobStep(
                      selected: _dateOfBirth,
                      onChanged: (d) => setState(() => _dateOfBirth = d),
                    ),
                    _YearsStep(
                      controller: _yearsController,
                      onChanged: (v) => setState(() => _yearsPlaying = v),
                    ),
                    _GreekExperienceStep(
                      selected: _greekExperience,
                      onChanged: _onGreekChanged,
                    ),
                    _InternationalStep(
                      selected: _internationalExperience,
                      careerHighRanking: _juniorCareerHighRanking,
                      rankingController: _rankingController,
                      receivedAtpWtaPoint: _receivedAtpWtaPoint,
                      usCollegeDivision: _usCollegeDivision,
                      onExperienceChanged: _onIntlChanged,
                      onRankingChanged: (v) =>
                          setState(() => _juniorCareerHighRanking = v),
                      onAtpWtaChanged: (v) =>
                          setState(() => _receivedAtpWtaPoint = v),
                      onDivisionChanged: (v) =>
                          setState(() => _usCollegeDivision = v),
                    ),
                    // Q5 is always included in the PageView but only reachable
                    // when _q5Active — navigation logic enforces this.
                    _OtherSportStep(
                      selected: _otherSport,
                      onChanged: (v) => setState(() => _otherSport = v),
                    ),
                  ],
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
                  if (_currentPage > 0) ...[
                    Expanded(
                      flex: 1,
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
                              _isLastPage
                                  ? l.questionnaireGetMyRating
                                  : l.actionNext,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Dot progress indicators ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  final completed = _isPageCompleted(i);
                  final isCurrent = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: completed
                          ? AppColors.primary
                          : isCurrent
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : AppColors.outline,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step: date of birth ───────────────────────────────────────────────────────

class _DobStep extends StatelessWidget {
  const _DobStep({required this.selected, required this.onChanged});
  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffoldCustom(
      question: l.questionnaireDobTitle,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selected ?? DateTime(1990),
            firstDate: DateTime(1930),
            lastDate: DateTime.now(),
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

// ── Step: years playing ───────────────────────────────────────────────────────

class _YearsStep extends StatelessWidget {
  const _YearsStep({
    required this.controller,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffoldCustom(
      question: l.questionnaireYearsTitle,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(
          hintText: l.questionnaireYearsHint,
          suffixText: l.questionnaireYearsUnit,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (v) {
          final n = int.tryParse(v);
          onChanged((n != null && n >= 0) ? n : null);
        },
      ),
    );
  }
}

// ── Step: Greek competitive experience ───────────────────────────────────────

class _GreekExperienceStep extends StatelessWidget {
  const _GreekExperienceStep(
      {required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
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
      selected: selected,
      onChanged: onChanged,
    );
  }
}

// ── Step: international experience (with inline sub-questions) ───────────────

class _InternationalStep extends StatelessWidget {
  const _InternationalStep({
    required this.selected,
    required this.careerHighRanking,
    required this.rankingController,
    required this.receivedAtpWtaPoint,
    required this.usCollegeDivision,
    required this.onExperienceChanged,
    required this.onRankingChanged,
    required this.onAtpWtaChanged,
    required this.onDivisionChanged,
  });

  final String? selected;
  final int? careerHighRanking;
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

          // None
          _OptionTile(
            label: l.questionnaireIntlNone,
            subtitle: l.questionnaireIntlNoneSub,
            selected: selected == 'none',
            onTap: () => onExperienceChanged('none'),
          ),

          // Recreational international
          _OptionTile(
            label: l.questionnaireIntlRecreational,
            subtitle: l.questionnaireIntlRecreationalSub,
            selected: selected == 'recreational_intl',
            onTap: () => onExperienceChanged('recreational_intl'),
          ),

          // Junior international
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

          // Professional international
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
                        label: 'Yes',
                        selected: receivedAtpWtaPoint == true,
                        onTap: () => onAtpWtaChanged(true),
                      ),
                      const SizedBox(width: 8),
                      _PillOption(
                        label: 'No',
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

          // US College
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
                    children: [
                      'Division I',
                      'Division II',
                      'Division III',
                      'NAIA',
                      'NJCAA',
                    ]
                        .map(
                          (d) => _PillOption(
                            label: d,
                            selected: usCollegeDivision == d,
                            onTap: () => onDivisionChanged(d),
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

// ── Step: other sport ─────────────────────────────────────────────────────────

class _OtherSportStep extends StatelessWidget {
  const _OtherSportStep({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      question: l.questionnaireOtherSportTitle,
      options: [
        _Option('racket_sports', l.questionnaireOtherSportRacket,
            l.questionnaireOtherSportRacketSub),
        _Option('other_sports', l.questionnaireOtherSportOther,
            l.questionnaireOtherSportOtherSub),
        _Option('none', l.questionnaireOtherSportNone,
            l.questionnaireOtherSportNoneSub),
      ],
      selected: selected,
      onChanged: onChanged,
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

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
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
  const _StepScaffoldCustom({required this.question, required this.child});
  final String question;
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  AppColors.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
            color:
                selected ? AppColors.primaryContainer : AppColors.surface,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? AppColors.primary : AppColors.onSurface,
                ),
          ),
        ),
      );
}
