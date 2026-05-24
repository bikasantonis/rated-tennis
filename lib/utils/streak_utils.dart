/// Counts the current consecutive win/loss streak from [matches] (newest first).
/// Returns positive for a win streak, negative for a loss streak, 0 if empty.
int computeWinStreak(List<Map<String, dynamic>> matches, String userId) {
  if (matches.isEmpty) return 0;
  int streak = 0;
  bool? streakWin;
  for (final m in matches) {
    final won = m['winner_id'] == userId;
    if (streakWin == null) {
      streakWin = won;
      streak = won ? 1 : -1;
    } else if (won == streakWin) {
      streak += won ? 1 : -1;
    } else {
      break;
    }
  }
  return streak;
}
