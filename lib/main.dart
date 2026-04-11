import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/app.dart';
import 'package:rated/services/notification_service.dart';

Future<void> main() async {
  // SentryFlutter.init wraps appRunner in its own zone.
  // WidgetsFlutterBinding.ensureInitialized and runApp must both be called
  // inside that zone — so all initialisation lives in appRunner.
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'dev',
      );
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // OneSignal — native only (no web implementation in onesignal_flutter).
      if (!kIsWeb) {
        OneSignal.initialize(const String.fromEnvironment('ONESIGNAL_APP_ID'));
        // Request permission on iOS; Android 13+ prompts on first notification.
        OneSignal.Notifications.requestPermission(false);
        NotificationService.instance.init();
      }

      // Supabase — values injected via --dart-define-from-file at build time.
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      runApp(const ProviderScope(child: RatedApp()));
    },
  );
}
