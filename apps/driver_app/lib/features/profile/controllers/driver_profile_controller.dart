import 'package:flutter/foundation.dart';

import '../../driver/models/driver_models.dart';
import '../../driver/services/driver_service.dart';
import '../models/profile_models.dart';

class DriverProfileController extends ChangeNotifier {
  DriverProfileController(this._driverService);

  final DriverService _driverService;

  DriverProfile? profile;
  bool loading = true;
  bool saving = false;
  bool changingPassword = false;
  String? error;
  bool initialized = false;

  Future<void> bootstrap() async {
    await loadProfile();
    initialized = true;
  }

  Future<void> loadProfile() async {
    loading = true;
    notifyListeners();
    try {
      profile = await _driverService.fetchProfile();
      error = null;
    } catch (e) {
      error = 'Không thể tải hồ sơ tài xế.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(DriverProfileUpdateRequest request) async {
    if (saving) return false;
    saving = true;
    notifyListeners();
    try {
      final updated = await _driverService.updateProfile(request);
      if (updated != null) {
        profile = updated;
        error = null;
        return true;
      }
    } catch (e) {
      error = 'Cập nhật thất bại, thử lại sau.';
    } finally {
      saving = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (changingPassword) return false;
    changingPassword = true;
    notifyListeners();
    try {
      final result = await _driverService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return result;
    } finally {
      changingPassword = false;
      notifyListeners();
    }
  }
}
