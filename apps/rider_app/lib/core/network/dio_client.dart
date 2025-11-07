import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

class DioClient {
  DioClient._internal();
  static final DioClient _i = DioClient._internal();
  factory DioClient() => _i;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: apiBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final _secure = const FlutterSecureStorage();
  bool _interceptorsConfigured = false;

  Dio get dio {
    if (!_interceptorsConfigured) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await _secure.read(key: 'auth_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              final prefs = await SharedPreferences.getInstance();
              final fallbackUser = prefs.getString('user_id') ?? 'demo-user';
              options.headers['X-User-Id'] = fallbackUser;
            }
            handler.next(options);
          },
          onError: (e, handler) {
            handler.next(e);
          },
        ),
      );
      _interceptorsConfigured = true;
    }
    return _dio;
  }
}
