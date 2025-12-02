import 'package:flutter/foundation.dart';

import '../../driver/models/driver_models.dart';
import '../../driver/services/driver_service.dart';
import '../../trips/models/trip_models.dart';
import '../../trips/services/trip_service.dart';

class DriverHomeController extends ChangeNotifier {
  DriverHomeController(this._driverService, this._tripService);

  final DriverService _driverService;
  final TripService _tripService;

  DriverProfile? driver;
  List<TripDetail> assignments = const [];
  bool loading = true;
  bool loadingTrips = true;
  bool togglingStatus = false;
  String? error;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    await Future.wait([
      _loadDriver(),
      _loadTrips(),
    ]);
    loading = false;
    notifyListeners();
  }

  Future<void> refreshTrips() async {
    await _loadTrips();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadDriver();
    notifyListeners();
  }

  Future<void> toggleAvailability(DriverAvailability next) async {
    if (driver == null || togglingStatus) return;
    togglingStatus = true;
    notifyListeners();
    final updated = await _driverService.toggleAvailability(driver!, next);
    if (updated != null) {
      driver = updated;
    }
    togglingStatus = false;
    notifyListeners();
  }

  Future<void> _loadDriver() async {
    try {
      driver = await _driverService.fetchProfile();
      error = null;
    } catch (e) {
      error = 'Không thể tải hồ sơ tài xế';
    }
  }

  Future<void> _loadTrips() async {
    try {
      loadingTrips = true;
      notifyListeners();
      final paged = await _tripService.listAssigned(limit: 20);
      assignments = paged.items;
      error = null;
      notifyListeners();
    } catch (e) {
      error = 'Không thể tải chuyến đi';
    } finally {
      loadingTrips = false;
      notifyListeners();
    }
  }
}
