import 'package:freezed_annotation/freezed_annotation.dart';

part 'tournament.freezed.dart';
part 'tournament.g.dart';

enum TournamentFormat { singleElimination, roundRobin }

enum TournamentStatus {
  draft,
  registrationOpen,
  inProgress,
  completed,
  cancelled,
}

@freezed
abstract class Tournament with _$Tournament {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Tournament({
    required String id,
    required String organizerId,
    String? clubId,
    required String name,
    String? description,
    required TournamentFormat format,
    required double eloMin,
    required double eloMax,
    required int maxPlayers,
    @Default(true) bool registrationOpen,
    required DateTime startsAt,
    DateTime? endsAt,
    required TournamentStatus status,
    @Default(1.0) double eloMultiplier,
    // ── Venue location ───────────────────────────────────────────────────────
    String? city,
    String? country,
    double? venueLat,
    double? venueLng,
    // ────────────────────────────────────────────────────────────────────────
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Tournament;

  factory Tournament.fromJson(Map<String, dynamic> json) =>
      _$TournamentFromJson(json);
}
