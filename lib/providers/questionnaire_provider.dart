import 'package:rated/screens/questionnaire/questionnaire_flow.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'questionnaire_provider.g.dart';

/// What `seed-elo` did with the submitted answers.
///
/// [ratingApplied] is false for a player who already has confirmed matches:
/// their answers and `seed_elo` are updated, but `elo_rating` is left alone so
/// a retake can never overwrite a rating earned by playing.
class SeedResult {
  const SeedResult({
    required this.seedElo,
    required this.ratingApplied,
    required this.currentElo,
    required this.matchesPlayed,
  });

  factory SeedResult.fromJson(Map<String, dynamic> json) {
    final seed = (json['seed_elo'] as num?)?.toDouble() ?? 0;
    return SeedResult(
      seedElo: seed,
      ratingApplied: json['rating_applied'] as bool? ?? true,
      currentElo: (json['current_elo'] as num?)?.toDouble() ?? seed,
      matchesPlayed: (json['matches_played'] as num?)?.toInt() ?? 0,
    );
  }

  /// The rating the answers computed to.
  final double seedElo;

  /// Whether [seedElo] was written to the profile.
  final bool ratingApplied;

  /// The player's rating after the call — equal to [seedElo] when applied.
  final double currentElo;
  final int matchesPlayed;
}

@riverpod
class QuestionnaireActions extends _$QuestionnaireActions {
  @override
  AsyncValue<SeedResult?> build() => const AsyncData(null);

  Future<void> submit(QuestionnaireAnswers answers) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<SeedResult?>(() async {
      final response = await Supabase.instance.client.functions.invoke(
        'seed-elo',
        body: toRequestBody(answers),
      );
      final data = response.data as Map<String, dynamic>?;
      if (response.status != 200) {
        throw Exception(data?['error'] ?? 'Failed to save questionnaire');
      }
      return SeedResult.fromJson(data ?? const {});
    });
  }
}
