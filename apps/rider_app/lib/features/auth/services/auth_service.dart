// lib/features/auth/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? phone;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, String?> toCache() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
      };
}

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPhone = 'user_phone';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secure = const FlutterSecureStorage();
  final Dio _dio = DioClient().dio;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      if (useMock) {
        await _persistMockSession(email: email, name: 'Demo User');
        return true;
      }

      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        await _persistSession(res.data as Map<String, dynamic>);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      if (useMock) {
        await _persistMockSession(email: email, name: name);
        return true;
      }

      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        if (phone != null) 'phone': phone,
      });

      if ((res.statusCode == 201 || res.statusCode == 200) &&
          res.data is Map<String, dynamic>) {
        await _persistSession(res.data as Map<String, dynamic>);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException(
          'Email đã tồn tại — vui lòng đăng nhập.',
        );
      }
      throw const AuthException('Đăng ký thất bại, vui lòng thử lại.');
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      if (useMock) {
        await Future.delayed(const Duration(milliseconds: 400));
        return email.isNotEmpty;
      }

      final res =
          await _dio.post('/auth/forgot-password', data: {'email': email});
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserPhone);
    await _secure.delete(key: _keyToken);
  }

  Future<bool> isLoggedIn() async {
    final token = await _secure.read(key: _keyToken);
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_keyUserId),
      'email': prefs.getString(_keyUserEmail),
      'name': prefs.getString(_keyUserName),
      'phone': prefs.getString(_keyUserPhone),
    };
  }

  Future<String?> getToken() async {
    return _secure.read(key: _keyToken);
  }

  Future<UserProfile?> me({bool forceRefresh = false}) async {
    if (useMock) {
      return const UserProfile(
        id: 'mock-user',
        email: 'mock@example.com',
        name: 'UIT-Go Rider',
        phone: '0900000000',
      );
    }

    if (!forceRefresh) {
      final cached = await _readCachedProfile();
      if (cached != null) return cached;
    }

    try {
      final res = await _dio.get('/auth/me');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final profile = UserProfile.fromJson(res.data as Map<String, dynamic>);
        await _cacheProfile(profile);
        return profile;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
    return null;
  }

  Future<UserProfile?> updateMe({String? name, String? phone}) async {
    if (useMock) {
      final updated = UserProfile(
        id: 'mock-user',
        email: 'mock@example.com',
        name: name ?? 'UIT-Go Rider',
        phone: phone ?? '0900000000',
      );
      await _cacheProfile(updated);
      return updated;
    }

    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (phone != null) payload['phone'] = phone;

      final res = await _dio.patch('/users/me', data: payload);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final profile = UserProfile.fromJson(res.data as Map<String, dynamic>);
        await _cacheProfile(profile);
        return profile;
      }
      return null;
    } on DioException catch (e) {
      throw AuthException(
        e.response?.data?['error']?.toString() ??
            'Không thể cập nhật thông tin. Vui lòng thử lại.',
      );
    }
  }

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
    } on DioException {
      return false;
    }
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final token = data['token'] as String? ?? '';
    if (token.isNotEmpty) {
      await _secure.write(key: _keyToken, value: token);
    }

    final profile = UserProfile(
      id: '${data['id'] ?? ''}',
      email: '${data['email'] ?? ''}',
      name: '${data['name'] ?? ''}',
    );
    await _cacheProfile(profile);
  }

  Future<void> _persistMockSession({
    required String email,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final mockToken = 'mock-token-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_keyToken, mockToken);
    await prefs.setString(_keyUserId, 'mock-user');
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserPhone, '0900000000');
    await _secure.write(key: _keyToken, value: mockToken);
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, profile.id);
    await prefs.setString(_keyUserEmail, profile.email);
    await prefs.setString(_keyUserName, profile.name);
    if (profile.phone != null) {
      await prefs.setString(_keyUserPhone, profile.phone!);
    }
  }

  Future<UserProfile?> _readCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyUserEmail);
    final name = prefs.getString(_keyUserName);
    if (id == null || email == null || name == null) {
      return null;
    }
    return UserProfile(
      id: id,
      email: email,
      name: name,
      phone: prefs.getString(_keyUserPhone),
    );
  }
}
