import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/config.dart';
import 'token_manager.dart';

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
  Future<bool>? _refreshingFuture;

  Dio get dio {
    if (!_interceptorsConfigured) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final provider = GlobalTokenManager.instance;
            String? token;
            if (provider != null) {
              token = await provider.accessToken();
            }
            token ??= await _secure.read(key: 'auth_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (e, handler) async {
            final provider = GlobalTokenManager.instance;
            final status = e.response?.statusCode ?? 0;
            final skipRefresh =
                e.requestOptions.extra['skipAuthRefresh'] == true;
            final alreadyRetried = e.requestOptions.extra['retried'] == true;
            if (provider != null &&
                status == 401 &&
                !skipRefresh &&
                !alreadyRetried) {
              final refreshed = await _refreshToken(provider);
              if (refreshed) {
                final newToken = await provider.accessToken();
                if (newToken != null && newToken.isNotEmpty) {
                  final requestOptions = e.requestOptions;
                  final headers =
                      Map<String, dynamic>.from(requestOptions.headers);
                  headers['Authorization'] = 'Bearer $newToken';
                  requestOptions
                    ..headers = headers
                    ..extra['retried'] = true;
                  try {
                    final response = await _dio.fetch(requestOptions);
                    return handler.resolve(response);
                  } on DioException catch (err) {
                    return handler.next(err);
                  }
                }
              }
            }
            handler.next(e);
          },
        ),
      );
      _interceptorsConfigured = true;
    }
    return _dio;
  }

  Future<bool> _refreshToken(AuthTokenProvider provider) async {
    if (_refreshingFuture != null) {
      return await _refreshingFuture!;
    }
    final future = provider.refreshToken();
    _refreshingFuture = future;
    try {
      return await future;
    } catch (_) {
      return false;
    } finally {
      _refreshingFuture = null;
    }
  }
}
