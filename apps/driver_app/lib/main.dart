import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/config/config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const DriverApp());
    return;
  }

  if (sentryDsn.isEmpty) {
    await _launchApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => _launchApp(),
  );
}

Future<void> _launchApp() async {
  final hasFirebaseConfig =
      DriverPushNotificationService.hasValidFirebaseConfig;

  if (hasFirebaseConfig) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (err) {
      debugPrint('Firebase init skipped: $err');
    }
  }

  final bool canUsePush = hasFirebaseConfig &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (canUsePush) {
    try {
      await DriverPushNotificationService.instance.init(
        navigatorKey: driverNavigatorKey,
      );
    } catch (err, stackTrace) {
      debugPrint('Push init failed: $err\n$stackTrace');
    }
  }

  runApp(const DriverApp());
}
