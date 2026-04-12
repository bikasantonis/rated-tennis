import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'questionnaire_provider.g.dart';

@riverpod
class QuestionnaireActions extends _$QuestionnaireActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit({
    required String playingFrequency,
    required String selfAssessedLevel,
    required int yearsPlaying,
    required String preferredSurface,
    required bool hasCompeted,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await Supabase.instance.client.functions.invoke(
        'seed-elo',
        body: {
          'playing_frequency': playingFrequency,
          'self_assessed_level': selfAssessedLevel,
          'years_playing': yearsPlaying,
          'preferred_surface': preferredSurface,
          'has_competed': hasCompeted,
        },
      );
      if (response.status != 200) {
        throw Exception(
          (response.data as Map<String, dynamic>?)?['error'] ?? 'Failed to save questionnaire',
        );
      }
    });
  }
}
