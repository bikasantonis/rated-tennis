import 'package:flutter_test/flutter_test.dart';
import 'package:rated/models/profile.dart';

void main() {
  group('EloTier.fromRating', () {
    // ── Exact boundary values ─────────────────────────────────────────────────

    test('5.0 → beginner (floor of the scale)', () {
      // The ELO scale starts at 5.0. The lowest band has no lower bound check,
      // so any rating below 6.0 must resolve to beginner.
      expect(EloTier.fromRating(5.0), EloTier.beginner);
    });

    test('5.9 → beginner (just below bronze threshold)', () {
      // 6.0 is the bronze boundary. 5.9 is strictly below it, so still beginner.
      expect(EloTier.fromRating(5.9), EloTier.beginner);
    });

    test('6.0 → bronze (exact lower boundary)', () {
      // The condition is rating >= 6.0, so 6.0 itself must be bronze, not beginner.
      expect(EloTier.fromRating(6.0), EloTier.bronze);
    });

    test('6.5 → bronze (mid-band)', () {
      expect(EloTier.fromRating(6.5), EloTier.bronze);
    });

    test('6.99 → bronze (just below silver threshold)', () {
      expect(EloTier.fromRating(6.99), EloTier.bronze);
    });

    test('7.0 → silver (exact lower boundary)', () {
      expect(EloTier.fromRating(7.0), EloTier.silver);
    });

    test('7.5 → silver (mid-band)', () {
      expect(EloTier.fromRating(7.5), EloTier.silver);
    });

    test('7.99 → silver (just below gold threshold)', () {
      expect(EloTier.fromRating(7.99), EloTier.silver);
    });

    test('8.0 → gold (exact lower boundary)', () {
      expect(EloTier.fromRating(8.0), EloTier.gold);
    });

    test('8.5 → gold (mid-band)', () {
      expect(EloTier.fromRating(8.5), EloTier.gold);
    });

    test('8.99 → gold (just below platinum threshold)', () {
      expect(EloTier.fromRating(8.99), EloTier.gold);
    });

    test('9.0 → platinum (exact lower boundary)', () {
      expect(EloTier.fromRating(9.0), EloTier.platinum);
    });

    test('9.4 → platinum (mid-band)', () {
      expect(EloTier.fromRating(9.4), EloTier.platinum);
    });

    test('9.49 → platinum (just below elite threshold)', () {
      // Elite starts at 9.5. 9.49 must still be platinum.
      expect(EloTier.fromRating(9.49), EloTier.platinum);
    });

    test('9.5 → elite (exact lower boundary)', () {
      // The elite condition is rating >= 9.5 and it is checked first in the
      // if-chain, so 9.5 must resolve to elite, not platinum.
      expect(EloTier.fromRating(9.5), EloTier.elite);
    });

    test('10.0 → elite (ceiling of the scale)', () {
      expect(EloTier.fromRating(10.0), EloTier.elite);
    });
  });
}
