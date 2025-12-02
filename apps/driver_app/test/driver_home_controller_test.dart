import 'package:driver_app/features/driver/models/driver_models.dart';
import 'package:driver_app/features/driver/services/driver_service.dart';
import 'package:driver_app/features/home/controllers/driver_home_controller.dart';
import 'package:driver_app/features/profile/models/profile_models.dart';
import 'package:driver_app/features/trips/models/trip_models.dart';
import 'package:driver_app/features/trips/services/trip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverHomeController', () {
    test('bootstrap loads driver profile and trips', () async {
      final driverService = _FakeDriverService();
      final tripService = _FakeTripService();
      final controller = DriverHomeController(driverService, tripService);

      await controller.bootstrap();

      expect(controller.loading, isFalse);
      expect(controller.driver, isNotNull);
      expect(controller.assignments, isNotEmpty);
      expect(controller.loadingTrips, isFalse);
      expect(controller.error, isNull);
    });

    test('toggleAvailability updates driver state', () async {
      final driverService = _FakeDriverService();
      final tripService = _FakeTripService();
      final controller = DriverHomeController(driverService, tripService);
      await controller.bootstrap();

      await controller.toggleAvailability(DriverAvailability.online);
      expect(controller.driver?.availability, DriverAvailability.online);
      expect(driverService.toggles, 1);
    });

    test('refreshTrips replaces assignments', () async {
      final driverService = _FakeDriverService();
      final tripService = _FakeTripService();
      final controller = DriverHomeController(driverService, tripService);
      await controller.bootstrap();
      tripService.assignments = [
        TripDetail(
          id: 'trip-200',
          riderId: 'rider-200',
          serviceId: 'bike',
          originText: 'UIT 1',
          destText: 'Dorm 1',
          status: TripStatus.arriving,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      await controller.refreshTrips();
      expect(controller.assignments.single.id, 'trip-200');
    });
  });
}

class _FakeDriverService implements DriverService {
  DriverProfile _profile = const DriverProfile(
    id: 'driver-1',
    userId: 'user-1',
    fullName: 'UIT Driver',
    phone: '0900',
    licenseNumber: 'UIT-DRIVER',
    rating: 4.9,
    availability: DriverAvailability.offline,
  );
  int toggles = 0;

  @override
  Future<DriverProfile?> fetchProfile() async {
    return _profile;
  }

  @override
  Future<DriverProfile?> toggleAvailability(
    DriverProfile profile,
    DriverAvailability status,
  ) async {
    toggles += 1;
    _profile = profile.copyWith(availability: status);
    return _profile;
  }

  @override
  Future<DriverProfile?> updateProfile(
    DriverProfileUpdateRequest request,
  ) async {
    _profile = _profile.copyWith(
      fullName: request.fullName,
      phone: request.phone,
      licenseNumber: request.licensePlate,
      vehicleType: request.vehicleType,
    );
    return _profile;
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return true;
  }
}

class _FakeTripService implements TripService {
  List<TripDetail> assignments = [
    TripDetail(
      id: 'trip-1',
      riderId: 'rider-1',
      serviceId: 'bike',
      originText: 'UIT Campus',
      destText: 'Dorm',
      status: TripStatus.requested,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> acceptTrip(String tripId) async {}

  @override
  Future<void> declineTrip(String tripId) async {}

  @override
  Future<TripDetail> fetchTrip(String tripId) async {
    return assignments.first;
  }

  @override
  Future<PagedTrips> listAssigned({int limit = 20, int offset = 0}) async {
    return PagedTrips(
      items: assignments,
      total: assignments.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> updateTripStatus(String tripId, TripStatus status) async {}
}
