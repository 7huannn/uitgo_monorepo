import 'package:dio/dio.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../models/driver_models.dart';
import '../../profile/models/profile_models.dart';

class DriverService {
  DriverService._internal() : _dio = DioClient().dio;
  DriverService._withClient(this._dio);
  static final DriverService _instance = DriverService._internal();
  factory DriverService() => _instance;
  static DriverService testInstance(Dio dio) => DriverService._withClient(dio);

  final Dio _dio;

  Future<DriverProfile?> fetchProfile() async {
    if (useMock) {
      return const DriverProfile(
        id: 'mock-driver',
        userId: 'mock-user',
        fullName: 'UIT-Go Driver',
        phone: '0900000000',
        licenseNumber: '59X1-00000',
        rating: 4.95,
        availability: DriverAvailability.offline,
        avatarUrl:
            'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=Driver',
        vehicleType: 'Xe máy',
      );
    }

    try {
      final res = await _dio.get('/v1/drivers/me');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return DriverProfile.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<DriverProfile?> toggleAvailability(
    DriverProfile profile,
    DriverAvailability status,
  ) async {
    if (useMock) {
      return profile.copyWith(availability: status);
    }

    final payload = {
      'status': status == DriverAvailability.online ? 'online' : 'offline'
    };
    final res =
        await _dio.patch('/v1/drivers/${profile.id}/status', data: payload);
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      final availability = driverAvailabilityFromString(
          (res.data as Map<String, dynamic>)['availability'] as String?);
      return profile.copyWith(availability: availability);
    }
    return profile;
  }

  Future<DriverProfile?> updateProfile(
    DriverProfileUpdateRequest request,
  ) async {
    if (useMock) {
      // TODO: Replace mock response with backend driver profile update.
      return DriverProfile(
        id: 'mock-driver',
        userId: 'mock-user',
        fullName: request.fullName,
        phone: request.phone,
        licenseNumber: request.licensePlate,
        rating: 4.95,
        availability: DriverAvailability.online,
        vehicleType: request.vehicleType,
        avatarUrl:
            'https://ui-avatars.com/api/?background=1B73E8&color=fff&name=${Uri.encodeComponent(request.fullName)}',
      );
    }

    final payload = request.toJson();
    try {
      final res = await _dio.patch('/v1/drivers/me', data: payload);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return DriverProfile.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: e.error ?? 'Không thể cập nhật hồ sơ. Vui lòng thử lại sau.',
      );
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return currentPassword.isNotEmpty && newPassword.length >= 6;
    }
    try {
      final res = await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }
}
