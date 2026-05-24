import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rated/models/court_theme.dart';
import 'package:rated/providers/auth_provider.dart';

final courtThemeProvider = Provider<CourtTheme>((ref) {
  final profile = ref.watch(currentProfileProvider).asData?.value;
  return CourtTheme.fromDbKey(profile?.courtTheme ?? 'roland_garros');
});
