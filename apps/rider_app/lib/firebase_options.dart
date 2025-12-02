import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Default Firebase configuration for UIT-Go Rider.
///
/// The placeholder values must be replaced with the actual Firebase project
/// settings (from `google-services.json` / `GoogleService-Info.plist`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_STORAGE_BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    iosBundleId: 'com.example.riderApp',
    storageBucket: 'REPLACE_WITH_STORAGE_BUCKET',
  );
}
