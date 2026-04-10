import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_request.freezed.dart';
part 'match_request.g.dart';

enum MatchRequestStatus { pending, accepted, declined, expired }

@freezed
abstract class MatchRequest with _$MatchRequest {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory MatchRequest({
    required String id,
    required String requesterId,
    required String recipientId,
    required DateTime proposedAt,
    String? venueNote,
    String? message,
    required MatchRequestStatus status,
    required DateTime expiresAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MatchRequest;

  factory MatchRequest.fromJson(Map<String, dynamic> json) =>
      _$MatchRequestFromJson(json);
}
