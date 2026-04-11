import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to record that the one-time post-registration questionnaire prompt
/// has already been shown for a given user ID.
String _promptKey(String userId) => 'q_prompt_$userId';

/// Returns true if the questionnaire prompt should still be shown for [userId].
/// Once [markQuestionnairePromptShown] is called the value flips to false and
/// is persisted across app restarts.
final questionnairePromptProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_promptKey(userId)) ?? false);
});

/// Marks the questionnaire prompt as having been shown for [userId].
/// Call this before showing the dialog so it is never shown a second time.
Future<void> markQuestionnairePromptShown(
    ProviderContainer container, String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_promptKey(userId), true);
  container.invalidate(questionnairePromptProvider(userId));
}
