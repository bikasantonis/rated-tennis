import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// ELO tier bands (PRD §7.2.3)
enum EloTier {
  beginner,
  bronze,
  silver,
  gold,
  platinum,
  elite;

  static EloTier fromRating(double rating) {
    if (rating >= 9.5) return EloTier.elite;
    if (rating >= 9.0) return EloTier.platinum;
    if (rating >= 8.0) return EloTier.gold;
    if (rating >= 7.0) return EloTier.silver;
    if (rating >= 6.0) return EloTier.bronze;
    return EloTier.beginner;
  }

  String get label => switch (this) {
        EloTier.beginner => 'Beginner',
        EloTier.bronze => 'Bronze',
        EloTier.silver => 'Silver',
        EloTier.gold => 'Gold',
        EloTier.platinum => 'Platinum',
        EloTier.elite => 'Elite',
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
