import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// ELO tier system — 11 numeric tiers at 0.5-point intervals (5.0 … 10.0).
/// The tier label is the numeric boundary itself (e.g. '7.0', '8.5').
/// A player's tier advances only when their true elo_rating crosses the next
/// 0.5-point threshold; no qualitative names are used.
enum EloTier {
  @JsonValue('5.0')  tier50,
  @JsonValue('5.5')  tier55,
  @JsonValue('6.0')  tier60,
  @JsonValue('6.5')  tier65,
  @JsonValue('7.0')  tier70,
  @JsonValue('7.5')  tier75,
  @JsonValue('8.0')  tier80,
  @JsonValue('8.5')  tier85,
  @JsonValue('9.0')  tier90,
  @JsonValue('9.5')  tier95,
  @JsonValue('10.0') tier100;

  /// Map the DB string (e.g. '7.5') to the enum value.
  static EloTier fromString(String s) => switch (s) {
        '5.5'  => tier55,
        '6.0'  => tier60,
        '6.5'  => tier65,
        '7.0'  => tier70,
        '7.5'  => tier75,
        '8.0'  => tier80,
        '8.5'  => tier85,
        '9.0'  => tier90,
        '9.5'  => tier95,
        '10.0' => tier100,
        _      => tier50,
      };

  /// The numeric label shown to the user (e.g. '7.0').
  String get label => switch (this) {
        tier50  => '5.0',
        tier55  => '5.5',
        tier60  => '6.0',
        tier65  => '6.5',
        tier70  => '7.0',
        tier75  => '7.5',
        tier80  => '8.0',
        tier85  => '8.5',
        tier90  => '9.0',
        tier95  => '9.5',
        tier100 => '10.0',
      };

  /// The elo_rating value at which this tier begins.
  double get threshold => switch (this) {
        tier50  => 5.0,
        tier55  => 5.5,
        tier60  => 6.0,
        tier65  => 6.5,
        tier70  => 7.0,
        tier75  => 7.5,
        tier80  => 8.0,
        tier85  => 8.5,
        tier90  => 9.0,
        tier95  => 9.5,
        tier100 => 10.0,
      };

  /// The next tier above this one, or null for tier100 (RATED — no next tier).
  EloTier? get nextTier => switch (this) {
        tier50  => tier55,
        tier55  => tier60,
        tier60  => tier65,
        tier65  => tier70,
        tier70  => tier75,
        tier75  => tier80,
        tier80  => tier85,
        tier85  => tier90,
        tier90  => tier95,
        tier95  => tier100,
        tier100 => null,
      };
}

enum UserRole { player, organizer, admin }

@freezed
abstract class Profile with _$Profile {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Profile({
    required String id,
    required String displayName,
    String? avatarUrl,
    String? clubId,
    required double eloRating,
    required EloTier eloTier,
    required UserRole role,
    required int matchesPlayed,
    required int matchesWon,
    @Default('en') String preferredLanguage,
    @Default(true) bool isPublic,
    @Default(false) bool questionnaireDone,
    // ── Stats ────────────────────────────────────────────────────────────────
    double? peakElo,
    // ── Location (GDPR Art. 6(1)(a) — explicit consent required) ────────────
    @Default(false) bool locationConsent,
    DateTime? locationConsentAt,
    String? homeCity,
    double? homeLat,
    double? homeLng,
    @Default(false) bool notifyNearbyTournaments,
    @Default(50) int nearbyRadiusKm,
    // ────────────────────────────────────────────────────────────────────────
    DateTime? deletedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
