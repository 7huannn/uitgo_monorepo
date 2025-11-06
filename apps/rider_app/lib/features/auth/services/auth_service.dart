// lib/features/auth/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// đường dẫn tới core theo cấu trúc thư mục bạn gửi:
import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secure = const FlutterSecureStorage();
  final Dio _dio = DioClient().dio;

  // LOGIN
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      if (useMock) {
        // --- MOCK LOCAL ---
        await Future.delayed(const Duration(milliseconds: 600));
        final prefs = await SharedPreferences.getInstance();
        final token = 'demo_token_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(_keyToken, token);
        await prefs.setString(_keyUserId, 'user_123');
        await prefs.setString(_keyUserEmail, email);
        await prefs.setString(_keyUserName, 'Demo User');
        await _secure.write(key: _keyToken, value: token); // để interceptor đọc
        return true;
      }

      // --- API THẬT ---
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final accessToken = (data['accessToken'] ?? data['token']) as String;
        final user = (data['user'] ?? {}) as Map<String, dynamic>;

        await _secure.write(key: _keyToken, value: accessToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, accessToken);
        if (user.isNotEmpty) {
          await prefs.setString(_keyUserId, '${user['id'] ?? user['_id'] ?? ''}');
          await prefs.setString(_keyUserEmail, '${user['email'] ?? ''}');
          await prefs.setString(_keyUserName, '${user['name'] ?? ''}');
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      // Inspect e.response?.statusCode / data nếu cần show message
      print('Login DioException: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // REGISTER
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      if (useMock) {
        await Future.delayed(const Duration(milliseconds: 500));
        return email.isNotEmpty && password.isNotEmpty && name.isNotEmpty;
      }

      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        if (phone != null) 'phone': phone,
      });

      return res.statusCode == 201 || res.statusCode == 200;
    } on DioException catch (e) {
      print('Register DioException: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  // RESET PASSWORD (quên mật khẩu)
  Future<bool> resetPassword({required String email}) async {
    try {
      if (useMock) {
        await Future.delayed(const Duration(milliseconds: 400));
        return email.isNotEmpty;
      }

      // Đổi endpoint theo BE của bạn (ví dụ: /auth/forgot-password)
      final res = await _dio.post('/auth/forgot-password', data: {'email': email});
      return res.statusCode == 200;
    } on DioException catch (e) {
      print('Reset password DioException: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    try {
      if (!useMock) {
        // Nếu BE có endpoint logout thì gọi, không có thì bỏ qua
        await _dio.post('/auth/logout').catchError((_) {});
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserName);
      await _secure.delete(key: _keyToken);
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // CHECK ĐÃ ĐĂNG NHẬP CHƯA
  Future<bool> isLoggedIn() async {
    try {
      final token = await _secure.read(key: _keyToken);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // LẤY USER INFO (từ cache local)
  Future<Map<String, String?>> getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'userId': prefs.getString(_keyUserId),
        'email': prefs.getString(_keyUserEmail),
        'name': prefs.getString(_keyUserName),
      };
    } catch (e) {
      return {};
    }
  }

  // LẤY TOKEN (từ secure storage)
  Future<String?> getToken() async {
    try {
      return await _secure.read(key: _keyToken);
    } catch (e) {
      return null;
    }
  }

  // UPDATE PROFILE
  Future<bool> updateProfile({String? name, String? phone}) async {
    try {
      if (useMock) {
        final prefs = await SharedPreferences.getInstance();
        if (name != null) await prefs.setString(_keyUserName, name);
        return true;
      }

      final res = await _dio.put('/auth/profile', data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      });

      if (res.statusCode == 200) {
        // Cập nhật cache local nếu BE trả lại user mới
        final prefs = await SharedPreferences.getInstance();
        final data = res.data;
        if (data is Map && data['name'] != null) {
          await prefs.setString(_keyUserName, '${data['name']}');
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  // ĐỔI MẬT KHẨU
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (useMock) {
        await Future.delayed(const Duration(milliseconds: 400));
        return currentPassword.isNotEmpty && newPassword.isNotEmpty;
      }

      final res = await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      return res.statusCode == 200;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }
}
