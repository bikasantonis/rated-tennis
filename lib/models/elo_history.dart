import 'package:freezed_annotation/freezed_annotation.dart';

part 'elo_history.freezed.dart';
part 'elo_history.g.dart';

enum EloEventType { match, tournamentMatch, decay, adminAdjustment }

@freezed
abstract class EloHistory with _$EloHistory {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory EloHistory({
    required String id,
    required String playerId,
    String? matchId,
    required double eloBefore,
    required double eloAfter,
    required double delta,
    required EloEventType eventType,
    required DateTime createdAt,
  }) = _EloHistory;

  factory EloHistory.fromJson(Map<String, dynamic> json) =>
      _$EloHistoryFromJson(json);
}
