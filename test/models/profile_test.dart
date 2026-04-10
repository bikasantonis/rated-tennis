import 'package:flutter_test/flutter_test.dart';
import 'package:rated/models/profile.dart';

// Minimal valid JSON that mirrors a Supabase profiles row (snake_case).
Map<String, dynamic> _baseJson() => {
      'id': 'abc-123',
      'display_name': 'Nikos P.',
      'avatar_url': null,
      'club_id': null,
      'elo_rating': 7.2,
      'elo_tier': 'silver',
      'role': 'player',
      'matches_played': 10,
      'matches_won': 6,
      'preferred_language': 'el',
      'is_public': true,
      'questionnaire_done': true,
      'deleted_at': null,
      'created_at': '2025-01-15T10:00:00.000Z',
      'updated_at': '2025-06-01T08:30:00.000Z',
    };

void main() {
  group('Profile.fromJson', () {
    test('deserialises a complete row correctly', () {
      // Verifies that every mapped field survives a round-trip through fromJson.
      // This catches snake_case → camelCase renames breaking after regeneration.
      final p = Profile.fromJson(_baseJson());

      expect(p.id, 'abc-123');
      expect(p.displayName, 'Nikos P.');
      expect(p.eloRating, 7.2);
      expect(p.eloTier, EloTier.silver);
      expect(p.role, UserRole.player);
      expect(p.matchesPlayed, 10);
      expect(p.matchesWon, 6);
      expect(p.preferredLanguage, 'el');
      expect(p.isPublic, isTrue);
      expect(p.questionnaireDone, isTrue);
      expect(p.deletedAt, isNull);
      expect(p.createdAt, DateTime.utc(2025, 1, 15, 10));
    });

    test('optional fields default correctly when absent', () {
      // Fields with @Default annotations must have the right fallback even when
      // the key is entirely missing from the JSON (e.g. older Supabase rows).
      final json = _baseJson()
        ..remove('preferred_language')
        ..remove('is_public')
        ..remove('questionnaire_done');

      final p = Profile.fromJson(json);

      expect(p.preferredLanguage, 'en');   // @Default('en')
      expect(p.isPublic, isTrue);          // @Default(true)
      expect(p.questionnaireDone, isFalse); // @Default(false)
    });

    test('null avatar_url and club_id are preserved as null', () {
      // Ensures nullable fields don't get coerced to empty strings.
      final p = Profile.fromJson(_baseJson());
      expect(p.avatarUrl, isNull);
      expect(p.clubId, isNull);
    });

    test('deleted_at is parsed when present', () {
      // Soft-deleted profiles have a non-null deleted_at timestamp.
      final json = _baseJson()
        ..['deleted_at'] = '2026-03-01T12:00:00.000Z';
      final p = Profile.fromJson(json);
      expect(p.deletedAt, DateTime.utc(2026, 3, 1, 12));
    });

    test('organizer role deserialises correctly', () {
      // Ensures the UserRole enum handles values beyond the default 'player'.
      final json = _baseJson()..['role'] = 'organizer';
      expect(Profile.fromJson(json).role, UserRole.organizer);
    });

    test('admin role deserialises correctly', () {
      final json = _baseJson()..['role'] = 'admin';
      expect(Profile.fromJson(json).role, UserRole.admin);
    });

    test('toJson → fromJson round-trip preserves all fields', () {
      // Guards against asymmetric serialisation: if toJson outputs a key that
      // fromJson cannot read back, the round-trip will diverge.
      final original = Profile.fromJson(_baseJson());
      final roundTripped = Profile.fromJson(original.toJson());
      expect(roundTripped, original);
    });
  });
}
