import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._auth);
  final AuthGateway _auth;

  bool _initialised = false;
  bool _loggedIn = false;
  bool get initializing => !_initialised;
  bool get loggedIn => _loggedIn;

  Future<void> bootstrap() async {
    if (_initialised) return;
    _loggedIn = await _auth.isLoggedIn();
    _initialised = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final success = await _auth.login(email: email, password: password);
    if (success) {
      _loggedIn = true;
      notifyListeners();
    }
    return success;
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
    final success = await _auth.registerDriver(
      name: name,
      email: email,
      phone: phone,
      password: password,
      licenseNumber: licenseNumber,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      plateNumber: plateNumber,
    );
    if (success) {
      _loggedIn = true;
      notifyListeners();
    }
    return success;
  }

  Future<void> logout() async {
    await _auth.logout();
    _loggedIn = false;
    notifyListeners();
  }
}
