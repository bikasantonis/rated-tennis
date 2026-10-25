import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/providers/questionnaire_provider.dart';
import 'package:rated/screens/questionnaire/questionnaire_flow.dart';
import 'package:rated/theme/app_colors.dart';

/// Shared plumbing for the three places that can open the questionnaire: the
/// home prompt, the profile CTA and the Settings row. Keeping the outcome copy
/// and the invalidation list here stops them drifting apart.

/// Whether [questionnaireVersion] is behind the current question set.
bool needsQuestionnaire(int questionnaireVersion) =>
    questionnaireVersion < kQuestionnaireVersion;

/// Everything that shows questionnaire answers or the rating they produced.
///
/// The rating itself only moves for a player with no matches, but the answers
/// and the playing-profile card change either way, so all of these are stale
/// after a submission.
void invalidateAfterQuestionnaire(WidgetRef ref, String playerId) {
  ref.invalidate(currentProfileProvider);
  ref.invalidate(playerProfileProvider(playerId));
  ref.invalidate(playerQuestionnaireProvider(playerId));
}

/// What to tell the player — the seed only becomes their rating when they have
/// no matches yet.
String seedResultMessage(AppLocalizations l, SeedResult result) =>
    result.ratingApplied
        ? l.questionnaireRatingApplied(result.seedElo.toStringAsFixed(1))
        : l.questionnaireRatingUnchanged(result.currentElo.toStringAsFixed(1));

SnackBar seedResultSnackBar(String message) => SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 5),
    );

/// Shows the outcome. Only safe where the calling screen stays on-screen; a
/// caller that pops first must capture the messenger beforehand and use
/// [seedResultMessage] with [seedResultSnackBar] instead.
void showSeedResultSnackBar(BuildContext context, SeedResult result) {
  ScaffoldMessenger.of(context).showSnackBar(
    seedResultSnackBar(seedResultMessage(AppLocalizations.of(context)!, result)),
  );
}
