import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final Dio _dio = DioClient().dio;

  Future<NotificationPageResult> listNotifications({
    bool unreadOnly = true,
    int limit = 20,
    int offset = 0,
  }) async {
    if (debugListNotifications != null) {
      return debugListNotifications!(
        unreadOnly: unreadOnly,
        limit: limit,
        offset: offset,
      );
    }
    if (useMock) {
      final now = DateTime.now();
      final items = List<AppNotification>.generate(
        3,
        (index) => AppNotification(
          id: 'mock-${index + 1}',
          title: index == 0 ? 'Chào mừng đến UIT-Go' : 'Khuyến mãi hấp dẫn',
          body: 'Thông báo demo số ${index + 1}',
          type: index == 0 ? 'system' : 'promotion',
          createdAt: now.subtract(Duration(hours: index * 3)),
          readAt: index == 0 ? now.subtract(const Duration(hours: 1)) : null,
        ),
      );
      final filtered =
          unreadOnly ? items.where((e) => !e.isRead).toList() : items;
      final slice = filtered.skip(offset).take(limit).toList();
      return NotificationPageResult(
        items: slice,
        total: filtered.length,
        limit: limit,
        offset: offset,
      );
    }

    final res = await _dio.get('/notifications', queryParameters: {
      'unreadOnly': unreadOnly,
      'limit': limit,
      'offset': offset,
    });

    return NotificationPageResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> markAsRead(String id) async {
    if (useMock) return;
    await _dio.patch('/notifications/$id/read');
  }
}

// Test injection hook
@visibleForTesting
typedef DebugListNotificationsFn = Future<NotificationPageResult> Function({
  bool unreadOnly,
  int limit,
  int offset,
});

@visibleForTesting
DebugListNotificationsFn? debugListNotifications;
