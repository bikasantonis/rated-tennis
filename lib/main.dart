import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/app.dart';
import 'package:rated/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise OneSignal push notifications
  OneSignal.initialize(const String.fromEnvironment('ONESIGNAL_APP_ID'));
  // Request permission on iOS; Android 13+ shows system dialog on first notification
  OneSignal.Notifications.requestPermission(false);
  NotificationService.instance.init();

  // Initialise Supabase — values injected via --dart-define-from-file.
  // detectSessionInUri (default true) automatically picks up the OAuth callback
  // from the deep link scheme registered in AndroidManifest.xml / Info.plist
  // (io.supabase.rated://login-callback).
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'dev',
      );
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(const ProviderScope(child: RatedApp())),
  );
}
