import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/trip_detail/pages/trip_detail_page.dart';
import '../../firebase_options.dart';
import 'notification_api.dart';

const _driverChannelId = 'driver_assignments';
const _driverChannelName = 'Trip assignments';
const _driverPrefsKey = 'driver_push_token';

@pragma('vm:entry-point')
Future<void> uitgoDriverFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class DriverPushNotificationService {
  DriverPushNotificationService._();

  static final DriverPushNotificationService instance =
      DriverPushNotificationService._();
  static bool get hasValidFirebaseConfig {
    if (kIsWeb) {
      return false;
    }
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      bool invalid(String value) =>
          value.isEmpty || value.contains('REPLACE_WITH');
      return !(invalid(options.appId) || invalid(options.apiKey));
    } catch (_) {
      return false;
    }
  }

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationApi _api = NotificationApi();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _configured = false;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (!isSupportedPlatform || _configured || !hasValidFirebaseConfig) {
      return;
    }

    _navigatorKey = navigatorKey;
    _messaging ??= FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(
      uitgoDriverFirebaseMessagingBackgroundHandler,
    );

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

    await _messaging!.requestPermission(alert: true, badge: true, sound: true);
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageInteraction);

    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }

    try {
      final token = await _messaging!.getToken();
      if (token != null) {
        await _syncDeviceToken(token);
      }
    } catch (err) {
      debugPrint('Failed to obtain FCM token: $err');
    }
    _messaging!.onTokenRefresh.listen((token) async {
      try {
        await _syncDeviceToken(token);
      } catch (err) {
        debugPrint('Failed to refresh FCM token: $err');
      }
    });

    _configured = true;
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _driverChannelId,
      _driverChannelName,
      description: 'New trip assignments and dispatch alerts',
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
        notification?.title ?? message.data['title'] ?? 'UIT-Go Driver';
    final body =
        notification?.body ?? message.data['body'] ?? 'Bạn có chuyến mới';
    final payload = jsonEncode(message.data);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _driverChannelId,
        _driverChannelName,
        channelDescription: 'New trip assignments and dispatch alerts',
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
      debugPrint('Driver payload parse error: $err');
    }
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final tripId = (data['tripId'] ?? data['tripID'])?.toString();
    if (tripId == null || tripId.isEmpty) {
      return;
    }
    final context = _navigatorKey?.currentContext;
    final navigator = _navigatorKey?.currentState;
    if (context == null || navigator == null) {
      return;
    }
    final auth = context.read<AuthController>();
    if (!auth.loggedIn) {
      debugPrint('User not logged in, skip navigating to trip.');
      return;
    }
    Future.microtask(() {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => TripDetailPage(tripId: tripId),
        ),
      );
    });
  }

  Future<void> _syncDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_driverPrefsKey-${_platformName()}';
    final previousToken = prefs.getString(cacheKey);
    if (previousToken == token) {
      return;
    }
    try {
      await _api.registerDeviceToken(
        platform: _platformName(),
        token: token,
      );
      await prefs.setString(cacheKey, token);
    } catch (err) {
      debugPrint('Failed to register driver push token: $err');
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
