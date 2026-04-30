import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/match_provider.dart';
import 'package:rated/providers/questionnaire_prompt_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/screens/questionnaire/questionnaire_screen.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/app_bar_actions.dart';
import 'package:rated/widgets/elo_score_card.dart';

/// SCR-04 — Home / Dashboard.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Prevents the dialog from being triggered more than once per screen lifetime.
  bool _promptScheduled = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);

    // When the profile first loads and questionnaire is not done, check whether
    // this is the first time the user has seen the prompt (registration only).
    ref.listen<AsyncValue<Profile?>>(currentProfileProvider, (_, next) {
      if (_promptScheduled) return;
      final profile = next.asData?.value;
      if (profile == null || profile.questionnaireDone) return;
      _promptScheduled = true;
      _maybeShowQuestionnairePrompt(profile.id);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: const [AppBarActions()],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
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
                    EloScoreCard(profile: profile),
                    const SizedBox(height: 24),
                    Text(
                      l.homeRecentMatches,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _RecentMatchesList(currentUserId: profile.id),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'challenge',
                  onPressed: () => context.push(AppRoutes.scheduleMatch),
                  icon: const Icon(Icons.sports_tennis),
                  label: const Text('Challenge'),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'submit',
        onPressed: () => context.push(AppRoutes.submitMatch),
        icon: const Icon(Icons.add),
        label: Text(l.homeSubmitMatch),
      ),
    );
  }

  /// Checks SharedPreferences; if the prompt has never been shown for this user,
  /// marks it as shown and then opens the two-step questionnaire dialog.
  Future<void> _maybeShowQuestionnairePrompt(String userId) async {
    final shouldShow =
        await ref.read(questionnairePromptProvider(userId).future);
    if (!shouldShow || !mounted) return;

    // Mark immediately so a hot-restart or rapid navigation cannot show it twice.
    await markQuestionnairePromptShown(ref.container, userId);
    if (!mounted) return;

    // Schedule after the current frame so we never call showDialog during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final takeQuestionnaire = await _showPromptDialog();
      if (takeQuestionnaire == true && mounted) {
        final completed = await showQuestionnaireDialog(context);
        if (completed == true) ref.invalidate(currentProfileProvider);
      }
    });
  }

  Future<bool?> _showPromptDialog() => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _QuestionnairePromptDialog(),
      );
}

// ---------------------------------------------------------------------------
// Questionnaire prompt dialog (two-step: prompt → optional confirmation)
// ---------------------------------------------------------------------------

class _QuestionnairePromptDialog extends StatelessWidget {
  const _QuestionnairePromptDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_tennis, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Before you start your RATED journey, we would like to ask you some questions to help us set up your first rating!',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'It will only take 1 minute',
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
              child: const Text('Take the questionnaire'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _onMaybeLater(context),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onMaybeLater(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
          'If you skip this, then you will start with a 5.0 beginner rating. '
          'Are you sure you want to skip it?',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("I'll take the questionnaire now"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.outline),
                child: const Text("Yes, I'm sure"),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // User confirmed they want to skip — close the outer dialog with false.
      Navigator.pop(context, false);
    }
    // If confirmed == false (chose "I'll take it now"), the skip dialog closes
    // and we fall back to the outer prompt dialog still visible.
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
    return (history.first as Map?)?['delta'] as double?;
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
            if (delta != null)
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
