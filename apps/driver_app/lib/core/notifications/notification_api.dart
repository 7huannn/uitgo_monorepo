import 'package:dio/dio.dart';

import '../config/config.dart';
import '../network/dio_client.dart';

class NotificationApi {
  NotificationApi() : _dio = DioClient().dio;

  final Dio _dio;

  Future<void> registerDeviceToken({
    required String platform,
    required String token,
  }) async {
    if (useMock) return;
    await _dio.post('/v1/notifications/register', data: {
      'platform': platform,
      'token': token,
    });
  }
}
