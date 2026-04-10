import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_result.freezed.dart';
part 'match_result.g.dart';

enum MatchStatus { pending, confirmed, disputed, overridden }

enum MatchType { friendly, tournament }

enum TournamentRound {
  group,
  @JsonValue('round_of_16') roundOf16,
  quarterfinal,
  semifinal,
  @JsonValue('final') final_,
}

enum MatchFormat {
  @JsonValue('bo3_standard') bo3Standard,
  @JsonValue('bo3_super_tb') bo3SuperTb,
  @JsonValue('bo3_mini_3rd') bo3Mini3rd,
  @JsonValue('bo3_mini_super') bo3MiniSuper,
  @JsonValue('one_full_set') oneFullSet,
  @JsonValue('one_mini_set') oneMiniSet,
}

/// Converts a [MatchFormat] to its database string value.
extension MatchFormatDb on MatchFormat {
  String get dbValue => switch (this) {
        MatchFormat.bo3Standard => 'bo3_standard',
        MatchFormat.bo3SuperTb => 'bo3_super_tb',
        MatchFormat.bo3Mini3rd => 'bo3_mini_3rd',
        MatchFormat.bo3MiniSuper => 'bo3_mini_super',
        MatchFormat.oneFullSet => 'one_full_set',
        MatchFormat.oneMiniSet => 'one_mini_set',
      };
}

@freezed
abstract class SetScore with _$SetScore {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SetScore({
    required int winner,
    required int loser,
  }) = _SetScore;

  factory SetScore.fromJson(Map<String, dynamic> json) =>
      _$SetScoreFromJson(json);
}

@freezed
abstract class MatchResult with _$MatchResult {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory MatchResult({
    required String id,
    required String submitterId,
    required String winnerId,
    required String loserId,
    required List<SetScore> score,
    required MatchType matchType,
    // Default matches the DB column default so historical rows deserialise cleanly.
    @Default(MatchFormat.bo3Standard) MatchFormat format,
    String? tournamentId,
    TournamentRound? tournamentRound,
    required MatchStatus status,
    String? disputedBy,
    List<SetScore>? disputeScore,
    String? resolvedBy,
    required DateTime playedAt,
    DateTime? confirmedAt,
    @Default(false) bool autoConfirmed,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MatchResult;

  factory MatchResult.fromJson(Map<String, dynamic> json) =>
      _$MatchResultFromJson(json);
}
