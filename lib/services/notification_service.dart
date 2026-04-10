import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../router/app_router.dart';

/// Wraps all OneSignal interactions.
///
/// Call [init] once from [main] after [OneSignal.initialize].
/// Call [identifyUser] after a successful Supabase sign-in.
/// Call [clearUser] on sign-out.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// The go_router instance must be set before notification taps can route.
  /// Assigned by [AppWidget] via [setRouter].
  GoRouter? _router;

  void setRouter(GoRouter router) => _router = router;

  /// Register listeners. Called once from [main] after [OneSignal.initialize].
  void init() {
    // Foreground: display the notification as an in-app banner (default
    // OneSignal behaviour — calling complete(notification) shows it).
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    // Tap handler: deep-link into the app using reference_type + reference_id
    // stored in the notification's additionalData payload.
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null || _router == null) return;
      final path = _resolveRoute(
        referenceType: data['reference_type'] as String?,
        referenceId: data['reference_id'] as String?,
      );
      if (path != null) _router!.push(path);
    });
  }

  /// Links the OneSignal subscription to the authenticated Supabase user.
  /// Must be called after sign-in so notifications reach the correct device.
  Future<void> identifyUser(String supabaseUserId) async {
    try {
      await OneSignal.login(supabaseUserId);
    } catch (e) {
      debugPrint('[NotificationService] login error: $e');
    }
  }

  /// Removes the user association from this device on sign-out.
  Future<void> clearUser() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('[NotificationService] logout error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Maps a [referenceType] / [referenceId] pair from a notification payload
  /// to a go_router path. Returns null if the type is unknown.
  String? _resolveRoute({
    required String? referenceType,
    required String? referenceId,
  }) {
    switch (referenceType) {
      case 'match_result':
        return AppRoutes.matchInbox;
      case 'match_request':
        return AppRoutes.matchInbox;
      case 'tournament':
        return referenceId != null ? '/tournaments/$referenceId' : AppRoutes.tournaments;
      case 'profile':
        return referenceId != null ? '/leaderboard/$referenceId' : AppRoutes.profile;
      default:
        return AppRoutes.home;
    }
  }
}
