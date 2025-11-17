import 'package:driver_app/features/auth/controllers/auth_controller.dart';
import 'package:driver_app/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthController', () {
    test('bootstrap caches logged-in state', () async {
      final gateway = _FakeAuthGateway(isLoggedInValue: true);
      final controller = AuthController(gateway);
      await controller.bootstrap();
      expect(controller.loggedIn, isTrue);
      expect(controller.initializing, isFalse);
    });

    test('login updates session and notifies listeners', () async {
      final gateway = _FakeAuthGateway();
      final controller = AuthController(gateway);
      var notified = 0;
      controller.addListener(() => notified++);

      final result = await controller.login('demo@uitgo.app', 'secret');
      expect(result, isTrue);
      expect(controller.loggedIn, isTrue);
      expect(notified, 1);
    });

    test('registerDriver populates session on success', () async {
      final gateway = _FakeAuthGateway();
      final controller = AuthController(gateway);
      final success = await controller.registerDriver(
        name: 'UIT Driver',
        email: 'driver@uitgo.app',
        phone: '0900000000',
        password: 'secret',
        licenseNumber: '59X1',
      );
      expect(success, isTrue);
      expect(controller.loggedIn, isTrue);
    });

    test('logout clears session flag', () async {
      final gateway = _FakeAuthGateway(isLoggedInValue: true);
      final controller = AuthController(gateway);
      await controller.bootstrap();
      expect(controller.loggedIn, isTrue);
      await controller.logout();
      expect(controller.loggedIn, isFalse);
      expect(gateway.logoutCalls, 1);
    });
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.isLoggedInValue = false});

  bool isLoggedInValue;
  int logoutCalls = 0;

  @override
  Future<bool> isLoggedIn() async => isLoggedInValue;

  @override
  Future<bool> login({required String email, required String password}) async {
    isLoggedInValue = true;
    return true;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    isLoggedInValue = false;
  }

  @override
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
    isLoggedInValue = true;
    return true;
  }
}
