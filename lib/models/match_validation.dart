// Pure score-validation logic, extracted from submit_match_screen.dart.
// Kept free of Flutter/widget dependencies so it can be unit tested directly.

import 'package:rated/models/match_result.dart';

// ── Set type classification ───────────────────────────────────────────────────

enum MatchSetType { full, mini, superTiebreak }

// ── Format configuration ──────────────────────────────────────────────────────

class MatchFormatConfig {
  const MatchFormatConfig({
    required this.setsToWin,
    required this.maxSets,
    required this.setTypes,
  });
  final int setsToWin;
  final int maxSets;
  final List<MatchSetType> setTypes; // positional — length == maxSets
}

MatchFormatConfig matchFormatConfig(MatchFormat format) => switch (format) {
      MatchFormat.bo3Standard => const MatchFormatConfig(
          setsToWin: 2,
          maxSets: 3,
          setTypes: [MatchSetType.full, MatchSetType.full, MatchSetType.full],
        ),
      MatchFormat.bo3SuperTb => const MatchFormatConfig(
          setsToWin: 2,
          maxSets: 3,
          setTypes: [
            MatchSetType.full,
            MatchSetType.full,
            MatchSetType.superTiebreak
          ],
        ),
      MatchFormat.bo3Mini3rd => const MatchFormatConfig(
          setsToWin: 2,
          maxSets: 3,
          setTypes: [MatchSetType.mini, MatchSetType.mini, MatchSetType.mini],
        ),
      MatchFormat.bo3MiniSuper => const MatchFormatConfig(
          setsToWin: 2,
          maxSets: 3,
          setTypes: [
            MatchSetType.mini,
            MatchSetType.mini,
            MatchSetType.superTiebreak
          ],
        ),
      MatchFormat.oneFullSet => const MatchFormatConfig(
          setsToWin: 1,
          maxSets: 1,
          setTypes: [MatchSetType.full],
        ),
      MatchFormat.oneMiniSet => const MatchFormatConfig(
          setsToWin: 1,
          maxSets: 1,
          setTypes: [MatchSetType.mini],
        ),
    };

// ── Per-set validation ────────────────────────────────────────────────────────

/// Returns true when (w, l) is a valid score for the given set type.
/// Rejects negative values first, then checks tennis rules.
/// The order of [w] and [l] does not matter — high/low are derived internally.
bool isValidSet(int w, int l, MatchSetType type) {
  if (w < 0 || l < 0) return false;
  final hi = w > l ? w : l;
  final lo = w > l ? l : w;
  return switch (type) {
    // Full set: 6-0..4, 7-5, 7-6
    MatchSetType.full =>
      (hi == 6 && lo <= 4) || (hi == 7 && lo == 5) || (hi == 7 && lo == 6),
    // Mini-set: 4-0..2, 5-3, 5-4
    MatchSetType.mini =>
      (hi == 4 && lo <= 2) || (hi == 5 && lo == 3) || (hi == 5 && lo == 4),
    // Super tie-break: first to 10, win by 2
    MatchSetType.superTiebreak => hi >= 10 && (hi - lo) >= 2,
  };
}

// ── Validation error types ────────────────────────────────────────────────────

sealed class MatchValidationError {
  const MatchValidationError();
}

final class InvalidSet extends MatchValidationError {
  const InvalidSet(this.setNumber);
  final int setNumber;
}

final class MatchIncomplete extends MatchValidationError {
  const MatchIncomplete();
}

final class WinnerMustWin extends MatchValidationError {
  const WinnerMustWin(this.setsNeeded);
  final int setsNeeded;
}

final class ExtraSets extends MatchValidationError {
  const ExtraSets();
}

// ── Match-level validation ────────────────────────────────────────────────────

/// A single set represented as (winner-column score, loser-column score).
/// The winner column always holds the declared match winner's scores.
typedef SetPair = ({int winner, int loser});

/// Validates [sets] against [format] rules.
///
/// Convention: [sets[i].winner] is the declared match winner's score for set i.
///
/// Returns null when the match is fully valid, otherwise a [MatchValidationError].
MatchValidationError? validateMatch(
  List<SetPair> sets,
  MatchFormat format,
) {
  final config = matchFormatConfig(format);

  // 0. Reject immediately if more sets were entered than the format allows.
  if (sets.length > config.maxSets) return const ExtraSets();

  // 1. Validate each set score against its positional type.
  for (int i = 0; i < sets.length; i++) {
    if (i >= config.setTypes.length) return InvalidSet(i + 1); // defensive
    if (!isValidSet(sets[i].winner, sets[i].loser, config.setTypes[i])) {
      return InvalidSet(i + 1);
    }
  }

  // 2. Walk sets in order: count wins and detect clinch violations.
  int wWins = 0;
  int lWins = 0;
  for (int i = 0; i < sets.length; i++) {
    if (sets[i].winner > sets[i].loser) {
      wWins++;
    } else {
      lWins++;
    }
    if (i < sets.length - 1) {
      if (wWins >= config.setsToWin || lWins >= config.setsToWin) {
        return const ExtraSets();
      }
    }
  }

  // 3. Ensure the match is complete.
  if (wWins < config.setsToWin && lWins < config.setsToWin) {
    return const MatchIncomplete();
  }

  // 4. The declared winner's column must have won enough sets.
  if (wWins != config.setsToWin) {
    return WinnerMustWin(config.setsToWin);
  }

  return null;
}
