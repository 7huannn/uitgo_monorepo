import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../firebase_options.dart';
import '../../features/notifications/services/notification_service.dart';

const _channelId = 'trip_updates';
const _channelName = 'Trip updates';
const _prefsKey = 'rider_push_token';

@pragma('vm:entry-point')
Future<void> uitgoRiderFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!PushNotificationService.isSupportedPlatform) {
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may already be initialized; ignore failures here.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _configured = false;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isSupportedPlatform || _configured) {
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (err) {
      debugPrint('Firebase init failed: $err');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      uitgoRiderFirebaseMessagingBackgroundHandler,
    );

    _messaging ??= FirebaseMessaging.instance;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _handleNavigationFromPayload(payload);
        }
      },
    );
    await _createNotificationChannel();

    final messaging = _messaging!;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission denied by the user.');
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageInteraction);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _syncDeviceToken(token);
    }
    messaging.onTokenRefresh.listen(_syncDeviceToken);

    _configured = true;
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Driver updates and trip status changes',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] ?? 'UIT-Go Rider';
    final body =
        notification?.body ?? message.data['body'] ?? 'Bạn có thông báo mới';
    final payload = jsonEncode(message.data);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Driver updates and trip status changes',
        importance: Importance.high,
        priority: Priority.high,
        icon: notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _handleMessageInteraction(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _handleNavigationFromPayload(String payload) {
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      _navigateFromData(data);
    } catch (err) {
      debugPrint('Failed to parse notification payload: $err');
    }
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final tripId = (data['tripId'] ?? data['tripID'])?.toString();
    if (tripId == null || tripId.isEmpty) {
      return;
    }
    Future.microtask(() {
      appRouter.go('/trips/$tripId/live');
    });
  }

  Future<void> _syncDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_prefsKey-${_platformName()}';
    final previousToken = prefs.getString(cacheKey);
    if (previousToken == token) {
      return;
    }
    try {
      await NotificationService().registerDeviceToken(
        platform: _platformName(),
        token: token,
      );
      await prefs.setString(cacheKey, token);
    } catch (err) {
      debugPrint('Failed to register push token: $err');
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
      default:
        return 'android';
    }
  }
}
