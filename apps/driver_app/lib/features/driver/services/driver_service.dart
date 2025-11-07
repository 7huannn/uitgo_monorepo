import 'package:dio/dio.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../models/driver_models.dart';

class DriverService {
  DriverService._internal();
  static final DriverService _instance = DriverService._internal();
  factory DriverService() => _instance;

  final Dio _dio = DioClient().dio;

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

    final payload = {'status': status == DriverAvailability.online ? 'online' : 'offline'};
    final res =
        await _dio.patch('/v1/drivers/${profile.id}/status', data: payload);
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      final availability =
          driverAvailabilityFromString((res.data as Map<String, dynamic>)['availability'] as String?);
      return profile.copyWith(availability: availability);
    }
    return profile;
  }

}
