import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/questionnaire_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';

/// SCR-03 — One-time skill questionnaire shown after registration.
/// Collects 5 answers that feed the seed-elo Edge Function.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  // Answers — null means not yet selected
  String? _playingFrequency;
  String? _selfAssessedLevel;
  int? _yearsPlaying;
  String? _preferredSurface;
  bool? _hasCompeted;

  bool get _currentAnswered => switch (_currentPage) {
        0 => _playingFrequency != null,
        1 => _selfAssessedLevel != null,
        2 => _yearsPlaying != null,
        3 => _preferredSurface != null,
        4 => _hasCompeted != null,
        _ => false,
      };

  bool get _isLastPage => _currentPage == 4;

  void _next() {
    if (_isLastPage) {
      _submit();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    await ref.read(questionnaireActionsProvider.notifier).submit(
          playingFrequency: _playingFrequency!,
          selfAssessedLevel: _selfAssessedLevel!,
          yearsPlaying: _yearsPlaying!,
          preferredSurface: _preferredSurface!,
          hasCompeted: _hasCompeted!,
        );

    if (!mounted) return;
    final state = ref.read(questionnaireActionsProvider);
    if (state is AsyncData) {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final questionnaireState = ref.watch(questionnaireActionsProvider);
    final isLoading = questionnaireState is AsyncLoading;
    final error = questionnaireState is AsyncError
        ? questionnaireState.error.toString()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.questionnaireTitle),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Progress indicator ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_currentPage + 1) / 5,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                Text(
                  'Step ${_currentPage + 1} of 5',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),

          // ── Question pages ─────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _FrequencyStep(
                  selected: _playingFrequency,
                  onChanged: (v) => setState(() => _playingFrequency = v),
                ),
                _LevelStep(
                  selected: _selfAssessedLevel,
                  onChanged: (v) => setState(() => _selfAssessedLevel = v),
                ),
                _YearsStep(
                  selected: _yearsPlaying,
                  onChanged: (v) => setState(() => _yearsPlaying = v),
                ),
                _SurfaceStep(
                  selected: _preferredSurface,
                  onChanged: (v) => setState(() => _preferredSurface = v),
                ),
                _CompetedStep(
                  selected: _hasCompeted,
                  onChanged: (v) => setState(() => _hasCompeted = v),
                ),
              ],
            ),
          ),

          // ── Error banner ───────────────────────────────────────────────────
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l.errorGeneric,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Navigation buttons ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : _back,
                      child: Text(l.actionBack),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
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
                        : Text(_isLastPage ? l.questionnaireGetMyRating : l.actionNext),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step widgets ──────────────────────────────────────────────────────────────

class _FrequencyStep extends StatelessWidget {
  const _FrequencyStep({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      question: l.questionnaireFrequencyTitle,
      options: [
        _Option('rarely', l.questionnaireFrequencyRarely, 'A few times a year or less'),
        _Option('monthly', l.questionnaireFrequencyMonthly, '1–2 times a month'),
        _Option('weekly', l.questionnaireFrequencyWeekly, '1–2 times a week'),
        _Option('multiple_weekly', l.questionnaireFrequencyMultiple, '3 or more times a week'),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      question: l.questionnaireLevelTitle,
      options: [
        _Option('beginner', l.questionnaireLevelBeginner, 'Still learning the basics'),
        _Option('intermediate', l.questionnaireLevelIntermediate, 'Consistent rallies, knows tactics'),
        _Option('advanced', l.questionnaireLevelAdvanced, 'Strong technique, plays tournaments'),
        _Option('competitive', l.questionnaireLevelCompetitive, 'Club/regional ranked player'),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

class _YearsStep extends StatelessWidget {
  const _YearsStep({required this.selected, required this.onChanged});
  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = [
      (label: 'Less than 1 year', sub: 'Just getting started', value: 0),
      (label: '1–3 years', sub: 'Building my game', value: 2),
      (label: '3–7 years', sub: 'Decent experience', value: 5),
      (label: '7+ years', sub: 'Seasoned player', value: 10),
    ];

    return _StepScaffoldCustom(
      question: l.questionnaireYearsTitle,
      child: Column(
        children: options
            .map(
              (o) => _OptionTile(
                label: o.label,
                subtitle: o.sub,
                selected: selected == o.value,
                onTap: () => onChanged(o.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SurfaceStep extends StatelessWidget {
  const _SurfaceStep({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffold(
      question: l.questionnaireSurfaceTitle,
      options: [
        _Option('clay', l.questionnaireSurfaceClay, 'Red or green clay courts'),
        _Option('hard', l.questionnaireSurfaceHard, 'Concrete or acrylic courts'),
        _Option('grass', l.questionnaireSurfaceGrass, 'Natural or artificial grass'),
        _Option('indoor', l.questionnaireSurfaceIndoor, 'Carpet or indoor hard courts'),
        _Option('no_preference', l.questionnaireSurfaceNoPreference, 'I play on any surface'),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

class _CompetedStep extends StatelessWidget {
  const _CompetedStep({required this.selected, required this.onChanged});
  final bool? selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _StepScaffoldCustom(
      question: l.questionnaireTournamentTitle,
      child: Column(
        children: [
          _OptionTile(
            label: l.questionnaireTournamentYes,
            subtitle: 'Club, regional, or national tournaments',
            selected: selected == true,
            onTap: () => onChanged(true),
          ),
          _OptionTile(
            label: l.questionnaireTournamentNo,
            subtitle: 'I play recreationally',
            selected: selected == false,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

// ── Reusable layout widgets ───────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    return _StepScaffoldCustom(
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
}

class _StepScaffoldCustom extends StatelessWidget {
  const _StepScaffoldCustom({required this.question, required this.child});
  final String question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
  Widget build(BuildContext context) {
    return Padding(
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
            color: selected
                ? AppColors.primaryContainer
                : AppColors.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
