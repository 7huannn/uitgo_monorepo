import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Dio get dio {
    // Interceptor gắn Authorization header tự động
    if (!_dio.interceptors.any((i) => i is InterceptorsWrapper)) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secure.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          // Gợi ý: nếu 401, có thể refresh token ở đây
          handler.next(e);
        },
      ));
    }
    return _dio;
  }
}
