import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
