import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:driver_app/features/driver/services/driver_service.dart';
import 'package:driver_app/features/profile/models/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverService profile', () {
    test('updateProfile sends request payload', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _StubAdapter((options) {
        captured = options;
        return _StubResponse(
          data: {
            'id': 'driver-1',
            'userId': 'user-1',
            'fullName': 'Test Driver',
            'phone': '0900000000',
            'licenseNumber': '59X1-00000',
            'rating': 4.8,
            'status': 'online',
            'vehicleType': 'Xe máy',
          },
        );
      });
      final service = DriverService.testInstance(dio);

      final updated = await service.updateProfile(
        const DriverProfileUpdateRequest(
          fullName: 'Test Driver',
          phone: '0900000000',
          licensePlate: '59X1-00000',
          vehicleType: 'Xe máy',
        ),
      );

      expect(captured?.uri.path, '/v1/drivers/me');
      expect(captured?.method, 'PATCH');
      expect(updated?.fullName, 'Test Driver');
      expect(updated?.licenseNumber, '59X1-00000');
    });

    test('changePassword posts to auth endpoint', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _StubAdapter((options) {
        captured = options;
        return const _StubResponse(statusCode: 200, data: {});
      });
      final service = DriverService.testInstance(dio);

      final ok = await service.changePassword(
        currentPassword: 'oldPass!',
        newPassword: 'newPass123',
      );

      expect(ok, isTrue);
      expect(captured?.uri.path, '/auth/change-password');
      expect(captured?.method, 'POST');
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final _StubResponse Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StubResponse {
  const _StubResponse({required this.data, this.statusCode = 200});

  final Object data;
  final int statusCode;
}
