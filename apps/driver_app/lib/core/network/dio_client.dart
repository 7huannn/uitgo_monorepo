import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

class DioClient {
  DioClient._internal();
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  final _secure = const FlutterSecureStorage();
  bool _configured = false;

  Dio get dio {
    if (!_configured) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await _secure.read(key: 'auth_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              final prefs = await SharedPreferences.getInstance();
              final fallbackUser = prefs.getString('user_id') ?? 'demo-driver';
              options.headers['X-User-Id'] = fallbackUser;
              options.headers['X-Role'] = 'driver';
            }
            handler.next(options);
          },
        ),
      );
      _configured = true;
    }
    return _dio;
  }
}
