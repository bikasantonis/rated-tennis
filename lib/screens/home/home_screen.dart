import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/providers/questionnaire_prompt_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/screens/questionnaire/questionnaire_entry.dart';
import 'package:rated/screens/questionnaire/questionnaire_flow.dart';
import 'package:rated/screens/questionnaire/questionnaire_screen.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/providers/court_theme_provider.dart';
import 'package:rated/utils/streak_utils.dart';
import 'package:rated/widgets/app_bar_actions.dart';
import 'package:rated/widgets/elo_score_card.dart';
import 'package:rated/widgets/error_state_widget.dart';
import 'package:rated/widgets/not_rated_chip.dart';

/// SCR-04 — Home / Dashboard.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _promptScheduled = false;
  bool _celebrationShown = false;
  late final ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);

    ref.listen<AsyncValue<Profile?>>(currentProfileProvider, (_, next) {
      if (_promptScheduled) return;
      final profile = next.asData?.value;
      // One condition covers both cases: never taken (version 0) and took an
      // older version (2), which is due a retake.
      if (profile == null ||
          profile.questionnaireVersion >= kQuestionnaireVersion) {
        return;
      }
      _promptScheduled = true;
      _maybeShowQuestionnairePrompt(profile);
    });

    // Fire confetti once when the newest confirmed match is a win.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(recentMatchesProvider,
        (_, next) {
      if (_celebrationShown) return;
      final matches = next.asData?.value ?? [];
      if (matches.isEmpty) return;
      final userId = ref.read(currentProfileProvider).asData?.value?.id;
      if (userId == null) return;
      if (matches.first['winner_id'] == userId) {
        _celebrationShown = true;
        _confettiCtrl.play();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        centerTitle: true,
        actions: const [AppBarActions()],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorStateWidget(),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final recentMatches =
              ref.watch(recentMatchesProvider).asData?.value ?? [];
          final streak = computeWinStreak(recentMatches, profile.id);
          final courtTheme = ref.watch(courtThemeProvider);

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(currentProfileProvider);
                  ref.invalidate(recentMatchesProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    EloScoreCard(
                      profile: profile,
                      accentColor: AppColors.aoBlue,
                      winStreak: streak,
                      courtTheme: courtTheme,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l.homeRecentMatches,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.aoBlue,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _RecentMatchesList(currentUserId: profile.id),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiCtrl,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 20,
                  colors: const [
                    AppColors.aoBlue,
                    AppColors.aoYellow,
                    AppColors.primary,
                  ],
                  shouldLoop: false,
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'challenge',
                  backgroundColor: AppColors.aoBlue,
                  foregroundColor: Colors.white,
                  onPressed: () => context.push(AppRoutes.scheduleMatch),
                  icon: const Icon(Icons.sports_tennis),
                  label: Text(l.homeChallenge),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'submit',
        backgroundColor: AppColors.aoBlue,
        foregroundColor: Colors.white,
        onPressed: () => context.push(AppRoutes.submitMatch),
        icon: const Icon(Icons.add),
        label: Text(l.homeSubmitMatch),
      ),
    );
  }

  Future<void> _maybeShowQuestionnairePrompt(Profile profile) async {
    final prompt =
        (userId: profile.id, version: kQuestionnaireVersion);
    final shouldShow =
        await ref.read(questionnairePromptProvider(prompt).future);
    if (!shouldShow || !mounted) return;

    await markQuestionnairePromptShown(ref.container, prompt);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final takeQuestionnaire = await _showPromptDialog(
        isRetake: profile.questionnaireVersion > 0,
        hasMatches: profile.matchesPlayed > 0,
      );
      if (takeQuestionnaire == true && mounted) {
        final result = await showQuestionnaireDialog(context);
        if (result != null && mounted) {
          showSeedResultSnackBar(context, result);
          invalidateAfterQuestionnaire(ref, profile.id);
        }
      }
    });
  }

  Future<bool?> _showPromptDialog({
    required bool isRetake,
    required bool hasMatches,
  }) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _QuestionnairePromptDialog(
          isRetake: isRetake,
          hasMatches: hasMatches,
        ),
      );
}

// ---------------------------------------------------------------------------
// Questionnaire prompt dialog (two-step: prompt → optional confirmation)
// ---------------------------------------------------------------------------

class _QuestionnairePromptDialog extends StatelessWidget {
  const _QuestionnairePromptDialog({
    required this.isRetake,
    required this.hasMatches,
  });

  /// True when the player already completed an older questionnaire version.
  final bool isRetake;

  /// True when the player has settled matches, so their rating will not move.
  final bool hasMatches;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final title =
        isRetake ? l.questionnaireRetakeTitle : l.questionnairePromptTitle;
    final subtitle = switch ((isRetake, hasMatches)) {
      (false, _) => l.questionnairePromptSubtitle,
      (true, false) => l.questionnaireRetakeSubtitle,
      (true, true) => l.questionnaireRetakeSubtitleRated,
    };

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_tennis, size: 48, color: AppColors.aoBlue),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isRetake ? l.questionnaireRetakeCta : l.questionnairePromptCta,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _onMaybeLater(context, l),
              child: Text(l.questionnairePromptLater),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onMaybeLater(BuildContext context, AppLocalizations l) async {
    // A retaker already has a rating, so the first-time warning about starting
    // at 5.0 would simply be untrue for them.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          isRetake
              ? l.questionnaireRetakeSkipConfirm
              : l.questionnairePromptSkipConfirm,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.questionnairePromptSkipStay),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.outline),
                child: Text(
                  isRetake
                      ? l.questionnaireRetakeSkipLeave
                      : l.questionnairePromptSkipLeave,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context, false);
    }
  }
}

// ── Recent matches list ───────────────────────────────────────────────────────

class _RecentMatchesList extends ConsumerWidget {
  const _RecentMatchesList({required this.currentUserId});
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(recentMatchesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(l.errorCouldNotLoadMatches,
          style: TextStyle(color: AppColors.error)),
      data: (matches) {
        if (matches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l.homeNoMatches,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.outline),
              ),
            ),
          );
        }
        return Column(
          children: matches
              .map((m) => _MatchTile(match: m, currentUserId: currentUserId))
              .toList(),
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.currentUserId});
  final Map<String, dynamic> match;
  final String currentUserId;

  String _formatScore(dynamic score) {
    if (score is! List) return '—';
    return score.map((s) { final m = s as Map; return '${m['winner']}–${m['loser']}'; }).join(', ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  double? get _eloDelta {
    final history = match['elo_history'] as List?;
    if (history == null || history.isEmpty) return null;
    // elo_history.delta is numeric(8,4); PostgREST decodes an integral value as
    // int, which `as double?` would silently turn into null.
    return ((history.first as Map?)?['delta'] as num?)?.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final winnerId = match['winner_id'] as String?;
    final won = winnerId == currentUserId;
    final winnerName =
        (match['winner'] as Map?)?['display_name'] as String? ?? 'Winner';
    final loserName =
        (match['loser'] as Map?)?['display_name'] as String? ?? 'Loser';
    final opponentName = won ? loserName : winnerName;
    final delta = _eloDelta;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: won
              ? AppColors.eloGain.withValues(alpha: 0.15)
              : AppColors.eloLoss.withValues(alpha: 0.15),
          child: Icon(
            won ? Icons.emoji_events_outlined : Icons.sports_tennis,
            color: won ? AppColors.eloGain : AppColors.eloLoss,
            size: 20,
          ),
        ),
        title: Text(
          won ? l.homeMatchWonVs(opponentName) : l.homeMatchLostVs(opponentName),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(_formatScore(match['score'])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (match['elo_excluded'] == true)
              const NotRatedChip()
            else if (delta != null)
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                style: TextStyle(
                  color: delta >= 0 ? AppColors.eloGain : AppColors.eloLoss,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            Text(
              _formatDate(match['played_at']),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
