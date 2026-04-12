import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once the user has passed biometric authentication for this app session,
/// or signed in fresh (biometric not required after a fresh login).
///
/// Starts false on every cold start — sessions restored from storage require
/// biometric re-authentication before accessing protected routes.
final biometricUnlockedProvider =
    NotifierProvider<_BiometricUnlockedNotifier, bool>(
  _BiometricUnlockedNotifier.new,
);

class _BiometricUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}
