import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'questionnaire_provider.g.dart';

@riverpod
class QuestionnaireActions extends _$QuestionnaireActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit({
    required DateTime dateOfBirth,
    required int yearsPlaying,
    required String greekExperience,
    required String internationalExperience,
    int? juniorCareerHighRanking,
    bool? receivedAtpWtaPoint,
    String? usCollegeDivision,
    String? otherSport,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await Supabase.instance.client.functions.invoke(
        'seed-elo',
        body: {
          'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
          'years_playing': yearsPlaying,
          'greek_experience': greekExperience,
          'international_experience': internationalExperience,
          'junior_career_high_ranking': juniorCareerHighRanking,
          'received_atp_wta_point': receivedAtpWtaPoint,
          'us_college_division': usCollegeDivision,
          'other_sport': otherSport,
        },
      );
      if (response.status != 200) {
        throw Exception(
          (response.data as Map<String, dynamic>?)?['error'] ??
              'Failed to save questionnaire',
        );
      }
    });
  }
}
