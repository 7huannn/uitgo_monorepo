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
}

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';
  static const _keyUserName = 'user_name';
  static const _keyUserPhone = 'user_phone';
  static const _keyUserRole = 'user_role';

  final _secure = const FlutterSecureStorage();
  final Dio _dio = DioClient().dio;

  Future<bool> login({required String email, required String password}) async {
    try {
      if (useMock) {
        await _persistMockSession(email: email);
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserRole);
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
      'role': prefs.getString(_keyUserRole),
    };
  }

  Future<void> _persistSession(Map<String, dynamic> json) async {
    final token = json['token'] as String? ?? '';
    final id = json['id']?.toString() ?? '';
    final email = json['email'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final role = json['role'] as String? ?? 'driver';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, id);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, name);
    if (json['phone'] is String && (json['phone'] as String).isNotEmpty) {
      await prefs.setString(_keyUserPhone, json['phone'] as String);
    }
    await prefs.setString(_keyUserRole, role);
    await _secure.write(key: _keyToken, value: token);
  }

  Future<void> _persistMockSession({required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, 'mock-driver');
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, 'UIT-Go Driver');
    await prefs.setString(_keyUserRole, 'driver');
    await _secure.write(key: _keyToken, value: 'mock-token');
  }

  Future<bool> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String licenseNumber,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? plateNumber,
  }) async {
    try {
      if (useMock) {
        await _persistMockSession(email: email);
        return true;
      }
      final payload = {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'licenseNumber': licenseNumber,
        'vehicle': {
          if (vehicleMake != null) 'make': vehicleMake,
          if (vehicleModel != null) 'model': vehicleModel,
          if (vehicleColor != null) 'color': vehicleColor,
          if (plateNumber != null) 'plateNumber': plateNumber,
        },
      };
      payload.removeWhere((key, value) => value is Map && value.isEmpty);
      final res = await _dio.post('/v1/drivers/register', data: payload);
      if ((res.statusCode == 201 || res.statusCode == 200) &&
          res.data is Map<String, dynamic>) {
        await _persistSession(res.data as Map<String, dynamic>);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException('Email đã tồn tại.');
      }
      throw const AuthException('Đăng ký thất bại, vui lòng thử lại.');
    }
  }
}
