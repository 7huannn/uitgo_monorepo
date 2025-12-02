import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.accessToken = '',
  });

  String baseUrl;
  String accessToken;

  Map<String, String> _headers({bool jsonBody = true}) {
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<bool> pingHealth() async {
    final uri = _uri('/health');
    final res = await http.get(uri);
    return res.statusCode == 200;
  }

  Future<AuthSession> login(String email, String password) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    _throwIfError(res);
    final body = _decode(res);
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      }),
    );
    _throwIfError(res);
    final body = _decode(res);
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String licenseNumber,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? plate,
  }) async {
    final res = await http.post(
      _uri('/v1/drivers/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'licenseNumber': licenseNumber,
        'vehicle': {
          'make': vehicleMake ?? '',
          'model': vehicleModel ?? '',
          'color': vehicleColor ?? '',
          'plateNumber': plate ?? '',
        },
      }),
    );
    _throwIfError(res);
    final body = _decode(res);
    return AuthSession.fromJson(body);
  }

  Future<UserProfile> me() async {
    final res = await http.get(_uri('/auth/me'), headers: _headers());
    _throwIfError(res);
    final body = _decode(res);
    return UserProfile.fromJson(body);
  }

  Future<UserProfile> adminMe() async {
    final res = await http.get(_uri('/admin/me'), headers: _headers());
    _throwIfError(res);
    final body = _decode(res);
    return UserProfile.fromJson(body);
  }

  Future<TripDetail> createTrip({
    required String originText,
    required String destText,
    required String serviceId,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  }) async {
    final res = await http.post(
      _uri('/v1/trips'),
      headers: _headers(),
      body: jsonEncode({
        'originText': originText,
        'destText': destText,
        'serviceId': serviceId,
        if (originLat != null) 'originLat': originLat,
        if (originLng != null) 'originLng': originLng,
        if (destLat != null) 'destLat': destLat,
        if (destLng != null) 'destLng': destLng,
      }),
    );
    _throwIfError(res);
    final body = _decode(res);
    return TripDetail.fromJson(body);
  }

  Future<TripDetail> fetchTrip(String id) async {
    final res = await http.get(_uri('/v1/trips/$id'), headers: _headers());
    _throwIfError(res);
    final body = _decode(res);
    return TripDetail.fromJson(body);
  }

  Future<void> updateTripStatus(String id, String status) async {
    final res = await http.patch(
      _uri('/v1/trips/$id/status'),
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    _throwIfError(res);
  }

  Future<void> assignDriver(String id, String driverId) async {
    final res = await http.post(
      _uri('/v1/trips/$id/assign'),
      headers: _headers(),
      body: jsonEncode({'driverId': driverId}),
    );
    _throwIfError(res);
  }

  Future<PagedUsers> listUsers({
    String role = '',
    String disabled = 'all',
    String q = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (role.trim().isNotEmpty && role.trim().toLowerCase() != 'all') {
      params['role'] = role.trim().toLowerCase();
    }
    final disabledLower = disabled.trim().toLowerCase();
    if (disabledLower == 'true' ||
        disabledLower == 'false' ||
        disabledLower == '1' ||
        disabledLower == '0') {
      params['disabled'] = disabledLower;
    } else if (disabledLower == 'active') {
      params['disabled'] = 'false';
    } else if (disabledLower == 'disabled') {
      params['disabled'] = 'true';
    }
    if (q.trim().isNotEmpty) {
      params['q'] = q.trim();
    }
    final res = await http.get(
      _uri('/admin/users', params: params),
      headers: _headers(jsonBody: false),
    );
    _throwIfError(res);
    final body = _decode(res);
    return PagedUsers.fromJson(body);
  }

  Future<UserProfile> updateUser({
    required String userId,
    String? role,
    bool? disabled,
  }) async {
    final payload = <String, dynamic>{};
    if (role != null) payload['role'] = role;
    if (disabled != null) payload['disabled'] = disabled;
    final res = await http.patch(
      _uri('/admin/users/$userId'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(res);
    final body = _decode(res);
    return UserProfile.fromJson(body);
  }

  Future<List<Promotion>> listPromotions() async {
    final res = await http.get(
      _uri('/admin/promotions'),
      headers: _headers(jsonBody: false),
    );
    _throwIfError(res);
    final body = res.body.trim();
    if (body.isEmpty) return <Promotion>[];
    final raw = jsonDecode(body) as List<dynamic>;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Promotion.fromJson)
        .toList();
  }

  Future<Promotion> createPromotion({
    required String title,
    required String description,
    required String code,
    required String gradientStart,
    required String gradientEnd,
    String? imageUrl,
    String? expiresAtRfc3339,
    int priority = 0,
  }) async {
    final res = await http.post(
      _uri('/admin/promotions'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'code': code,
        'gradientStart': gradientStart,
        'gradientEnd': gradientEnd,
        'priority': priority,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (expiresAtRfc3339 != null && expiresAtRfc3339.isNotEmpty)
          'expiresAt': expiresAtRfc3339,
      }),
    );
    _throwIfError(res);
    final body = _decode(res);
    return Promotion.fromJson(body);
  }

  Future<void> deletePromotion(String id) async {
    final res = await http.delete(
      _uri('/admin/promotions/$id'),
      headers: _headers(jsonBody: false),
    );
    _throwIfError(res);
  }

  Uri _uri(String path, {Map<String, String>? params}) {
    final base = Uri.parse(baseUrl.trim());
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    var basePath = base.path;
    if (basePath.isEmpty) {
      basePath = '/';
    } else if (!basePath.endsWith('/')) {
      basePath = '$basePath/';
    }
    final fullPath = '$basePath$sanitizedPath';
    return base.replace(path: fullPath, queryParameters: params);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return <String, dynamic>{};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    final msg = res.body.isNotEmpty ? res.body : 'HTTP ${res.statusCode}';
    throw HttpException('HTTP ${res.statusCode}: $msg');
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
