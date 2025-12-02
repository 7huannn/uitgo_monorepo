import 'package:dio/dio.dart';
import 'package:driver_app/features/driver/models/driver_models.dart';
import 'package:driver_app/features/driver/services/driver_service.dart';
import 'package:driver_app/features/profile/controllers/driver_profile_controller.dart';
import 'package:driver_app/features/profile/models/profile_models.dart';
import 'package:driver_app/features/profile/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('DriverProfilePage', () {
    testWidgets('renders existing profile data', (tester) async {
      final controller = _FakeProfileController();
      controller.setProfile(const DriverProfile(
        id: 'd1',
        userId: 'u1',
        fullName: 'UIT Driver',
        phone: '0901234567',
        licenseNumber: '59X1-12345',
        rating: 4.9,
        availability: DriverAvailability.online,
        vehicleType: 'Xe máy',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriverProfileController>.value(
            value: controller,
            child: const DriverProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UIT Driver'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('59X1-12345'), findsOneWidget);
    });

    testWidgets('triggers save when form submitted', (tester) async {
      final controller = _FakeProfileController();
      controller.setProfile(const DriverProfile(
        id: 'd1',
        userId: 'u1',
        fullName: 'UIT Driver',
        phone: '0901234567',
        licenseNumber: '59X1-12345',
        rating: 4.9,
        availability: DriverAvailability.online,
        vehicleType: 'Xe máy',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriverProfileController>.value(
            value: controller,
            child: const DriverProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'New Name');

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(controller.updateCalled, isTrue);
    });
  });
}

class _FakeProfileController extends DriverProfileController {
  _FakeProfileController()
      : super(DriverService.testInstance(
            Dio(BaseOptions(baseUrl: 'https://example.com'))));

  bool updateCalled = false;

  void setProfile(DriverProfile profile) {
    super.profile = profile;
    loading = false;
    initialized = true;
    notifyListeners();
  }

  @override
  Future<void> loadProfile() async {}

  @override
  Future<bool> updateProfile(DriverProfileUpdateRequest request) async {
    updateCalled = true;
    profile = profile?.copyWith(fullName: request.fullName);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return true;
  }
}
