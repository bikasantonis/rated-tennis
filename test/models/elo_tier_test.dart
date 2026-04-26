import 'package:flutter_test/flutter_test.dart';
import 'package:rated/models/profile.dart';

void main() {
  group('EloTier.fromRating', () {
    // ── tier50 band: [5.0, 5.5) ───────────────────────────────────────────────

    test('5.0 → tier50 (floor of the scale)', () {
      expect(EloTier.fromRating(5.0), EloTier.tier50);
    });

    test('5.4 → tier50 (just below tier55 threshold)', () {
      expect(EloTier.fromRating(5.4), EloTier.tier50);
    });

    // ── tier55 band: [5.5, 6.0) ───────────────────────────────────────────────

    test('5.5 → tier55 (exact lower boundary)', () {
      expect(EloTier.fromRating(5.5), EloTier.tier55);
    });

    test('5.9 → tier55 (just below tier60 threshold)', () {
      expect(EloTier.fromRating(5.9), EloTier.tier55);
    });

    // ── tier60 band: [6.0, 6.5) ───────────────────────────────────────────────

    test('6.0 → tier60 (exact lower boundary)', () {
      expect(EloTier.fromRating(6.0), EloTier.tier60);
    });

    test('6.3 → tier60 (mid-band)', () {
      expect(EloTier.fromRating(6.3), EloTier.tier60);
    });

    // ── tier65 band: [6.5, 7.0) ───────────────────────────────────────────────

    test('6.5 → tier65 (exact lower boundary)', () {
      expect(EloTier.fromRating(6.5), EloTier.tier65);
    });

    test('6.99 → tier65 (just below tier70 threshold)', () {
      expect(EloTier.fromRating(6.99), EloTier.tier65);
    });

    // ── tier70 band: [7.0, 7.5) ───────────────────────────────────────────────

    test('7.0 → tier70 (exact lower boundary)', () {
      expect(EloTier.fromRating(7.0), EloTier.tier70);
    });

    test('7.3 → tier70 (mid-band)', () {
      expect(EloTier.fromRating(7.3), EloTier.tier70);
    });

    // ── tier75 band: [7.5, 8.0) ───────────────────────────────────────────────

    test('7.5 → tier75 (exact lower boundary)', () {
      expect(EloTier.fromRating(7.5), EloTier.tier75);
    });

    test('7.99 → tier75 (just below tier80 threshold)', () {
      expect(EloTier.fromRating(7.99), EloTier.tier75);
    });

    // ── tier80 band: [8.0, 8.5) ───────────────────────────────────────────────

    test('8.0 → tier80 (exact lower boundary)', () {
      expect(EloTier.fromRating(8.0), EloTier.tier80);
    });

    test('8.3 → tier80 (mid-band)', () {
      expect(EloTier.fromRating(8.3), EloTier.tier80);
    });

    // ── tier85 band: [8.5, 9.0) ───────────────────────────────────────────────

    test('8.5 → tier85 (exact lower boundary)', () {
      expect(EloTier.fromRating(8.5), EloTier.tier85);
    });

    test('8.99 → tier85 (just below tier90 threshold)', () {
      expect(EloTier.fromRating(8.99), EloTier.tier85);
    });

    // ── tier90 band: [9.0, 9.5) ───────────────────────────────────────────────

    test('9.0 → tier90 (exact lower boundary)', () {
      expect(EloTier.fromRating(9.0), EloTier.tier90);
    });

    test('9.49 → tier90 (just below tier95 threshold)', () {
      expect(EloTier.fromRating(9.49), EloTier.tier90);
    });

    // ── tier95 band: [9.5, 10.0) ──────────────────────────────────────────────

    test('9.5 → tier95 (exact lower boundary)', () {
      expect(EloTier.fromRating(9.5), EloTier.tier95);
    });

    test('9.8 → tier95 (mid-band)', () {
      expect(EloTier.fromRating(9.8), EloTier.tier95);
    });

    // ── tier100 band: [10.0, ∞) ───────────────────────────────────────────────

    test('10.0 → tier100 (ceiling of the scale)', () {
      expect(EloTier.fromRating(10.0), EloTier.tier100);
    });
  });
}
