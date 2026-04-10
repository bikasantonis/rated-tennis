import 'package:flutter_test/flutter_test.dart';
import 'package:rated/models/match_result.dart';
import 'package:rated/models/match_validation.dart';

// Convenience helper — builds a SetPair list from plain int pairs.
List<SetPair> sets(List<(int, int)> raw) =>
    raw.map((p) => (winner: p.$1, loser: p.$2)).toList();

void main() {
  // ── isValidSet — full set ───────────────────────────────────────────────────

  group('isValidSet — full set', () {
    test('6-0 is valid (clean bagel)', () {
      // The lowest legal full-set score. hi == 6, lo == 0, lo <= 4.
      expect(isValidSet(6, 0, MatchSetType.full), isTrue);
    });

    test('6-4 is valid (hi boundary of the 6-x band)', () {
      // hi == 6, lo == 4 — the last allowed score before 7-5 territory.
      expect(isValidSet(6, 4, MatchSetType.full), isTrue);
    });

    test('6-5 is invalid (not a legal full-set finish)', () {
      // 6-5 is not a recognised terminal score; play continues to 7-5 or TB.
      expect(isValidSet(6, 5, MatchSetType.full), isFalse);
    });

    test('7-5 is valid', () {
      expect(isValidSet(7, 5, MatchSetType.full), isTrue);
    });

    test('7-6 is valid (tie-break set)', () {
      expect(isValidSet(7, 6, MatchSetType.full), isTrue);
    });

    test('7-4 is invalid (7 is only reachable from 6-5 or 6-6)', () {
      expect(isValidSet(7, 4, MatchSetType.full), isFalse);
    });

    test('negative scores are rejected', () {
      // Guard against bad input — negative values must never pass.
      expect(isValidSet(-1, 6, MatchSetType.full), isFalse);
      expect(isValidSet(6, -1, MatchSetType.full), isFalse);
    });

    test('order of w/l does not matter (6-0 and 0-6 are both valid)', () {
      // The function normalises to hi/lo internally, so caller order is irrelevant.
      expect(isValidSet(0, 6, MatchSetType.full), isTrue);
    });
  });

  // ── isValidSet — mini set ───────────────────────────────────────────────────

  group('isValidSet — mini set', () {
    test('4-0 is valid', () {
      expect(isValidSet(4, 0, MatchSetType.mini), isTrue);
    });

    test('4-2 is valid (hi boundary of the 4-x band)', () {
      expect(isValidSet(4, 2, MatchSetType.mini), isTrue);
    });

    test('4-3 is invalid (not a recognised mini-set finish)', () {
      // Play would continue to 5-3 or 5-4; 4-3 is mid-game.
      expect(isValidSet(4, 3, MatchSetType.mini), isFalse);
    });

    test('5-3 is valid', () {
      expect(isValidSet(5, 3, MatchSetType.mini), isTrue);
    });

    test('5-4 is valid (mini tie-break equivalent)', () {
      expect(isValidSet(5, 4, MatchSetType.mini), isTrue);
    });

    test('5-2 is invalid', () {
      expect(isValidSet(5, 2, MatchSetType.mini), isFalse);
    });
  });

  // ── isValidSet — super tie-break ────────────────────────────────────────────

  group('isValidSet — super tie-break', () {
    test('10-8 is valid (minimum legal super TB score)', () {
      // First to 10, win by 2. 10-8 satisfies both conditions exactly.
      expect(isValidSet(10, 8, MatchSetType.superTiebreak), isTrue);
    });

    test('10-9 is invalid (win by only 1)', () {
      // hi - lo == 1, fails the win-by-2 rule.
      expect(isValidSet(10, 9, MatchSetType.superTiebreak), isFalse);
    });

    test('11-9 is valid (extended past 10)', () {
      expect(isValidSet(11, 9, MatchSetType.superTiebreak), isTrue);
    });

    test('15-13 is valid (long super TB)', () {
      expect(isValidSet(15, 13, MatchSetType.superTiebreak), isTrue);
    });

    test('9-7 is invalid (neither player reached 10)', () {
      expect(isValidSet(9, 7, MatchSetType.superTiebreak), isFalse);
    });
  });

  // ── validateMatch — bo3Standard ────────────────────────────────────────────

  group('validateMatch — bo3Standard (best of 3, all full sets)', () {
    test('2-0 sweep is valid', () {
      // Winner takes both sets cleanly. No 3rd set needed.
      final result = validateMatch(
        sets([(6, 3), (6, 4)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isNull);
    });

    test('2-1 comeback is valid', () {
      // Winner loses set 1, wins sets 2 and 3.
      final result = validateMatch(
        sets([(3, 6), (6, 4), (6, 3)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isNull);
    });

    test('extra set after clinch returns ExtraSets', () {
      // Winner already has 2 sets after set 2; a 3rd set should not exist.
      // The winner column has 6,6,6 but the match was decided at 2-0.
      final result = validateMatch(
        sets([(6, 3), (6, 3), (6, 3)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isA<ExtraSets>());
    });

    test('only one set entered returns MatchIncomplete', () {
      // One set played, nobody has reached 2 wins yet.
      final result = validateMatch(
        sets([(6, 3)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isA<MatchIncomplete>());
    });

    test('invalid set score returns InvalidSet with correct set number', () {
      // Set 1 is 6-5 which is not a legal full-set score.
      final result = validateMatch(
        sets([(6, 5), (6, 3)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isA<InvalidSet>());
      expect((result as InvalidSet).setNumber, 1);
    });

    test('loser column winning enough sets returns WinnerMustWin', () {
      // The loser column wins 2 sets, declared winner only wins 1.
      // validateMatch treats the first element of each pair as the winner column,
      // so (3,6) means the declared winner scored 3, loser scored 6.
      final result = validateMatch(
        sets([(3, 6), (3, 6)]),
        MatchFormat.bo3Standard,
      );
      expect(result, isA<WinnerMustWin>());
    });
  });

  // ── validateMatch — bo3SuperTb ──────────────────────────────────────────────

  group('validateMatch — bo3SuperTb (2 full sets + super TB decider)', () {
    test('valid 2-1 with super TB decider 10-8', () {
      // Set 3 is a super tie-break, not a full set.
      final result = validateMatch(
        sets([(3, 6), (6, 3), (10, 8)]),
        MatchFormat.bo3SuperTb,
      );
      expect(result, isNull);
    });

    test('full-set score in super TB slot returns InvalidSet', () {
      // 6-3 is valid for a full set but not for a super tie-break position.
      final result = validateMatch(
        sets([(3, 6), (6, 3), (6, 3)]),
        MatchFormat.bo3SuperTb,
      );
      expect(result, isA<InvalidSet>());
      expect((result as InvalidSet).setNumber, 3);
    });
  });

  // ── validateMatch — oneFullSet ──────────────────────────────────────────────

  group('validateMatch — oneFullSet (single full set)', () {
    test('6-4 is a valid and complete match', () {
      final result = validateMatch(
        sets([(6, 4)]),
        MatchFormat.oneFullSet,
      );
      expect(result, isNull);
    });

    test('two sets entered returns ExtraSets', () {
      // Format only allows 1 set; a second set means the match was already over.
      final result = validateMatch(
        sets([(6, 4), (6, 3)]),
        MatchFormat.oneFullSet,
      );
      expect(result, isA<ExtraSets>());
    });
  });

  // ── validateMatch — oneMiniSet ──────────────────────────────────────────────

  group('validateMatch — oneMiniSet (single mini set)', () {
    test('4-1 is valid', () {
      final result = validateMatch(
        sets([(4, 1)]),
        MatchFormat.oneMiniSet,
      );
      expect(result, isNull);
    });

    test('full-set score in mini slot returns InvalidSet', () {
      // 6-3 is only legal for a full set, not a mini set.
      final result = validateMatch(
        sets([(6, 3)]),
        MatchFormat.oneMiniSet,
      );
      expect(result, isA<InvalidSet>());
    });
  });
}
