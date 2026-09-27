import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifies one prompt: a given user, for a given questionnaire version.
typedef QuestionnairePrompt = ({String userId, int version});

/// Key recording that the questionnaire prompt has already been shown.
///
/// Scoped by version on purpose. Without it, every player who dismissed the v2
/// prompt would carry a `true` flag forever and would never be asked to retake
/// when a new version ships. Keys from older versions are simply orphaned.
String _promptKey(QuestionnairePrompt p) =>
    'q_prompt_v${p.version}_${p.userId}';

/// Whether the prompt for [p] should still be shown.
final questionnairePromptProvider =
    FutureProvider.family<bool, QuestionnairePrompt>((ref, p) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_promptKey(p)) ?? false);
});

/// Marks the prompt for [p] as shown. Call this before showing the dialog so it
/// is never shown a second time for this version.
Future<void> markQuestionnairePromptShown(
    ProviderContainer container, QuestionnairePrompt p) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_promptKey(p), true);
  container.invalidate(questionnairePromptProvider(p));
}
