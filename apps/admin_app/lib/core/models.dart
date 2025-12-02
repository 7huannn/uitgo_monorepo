class AuthSession {
  AuthSession({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      accessToken:
          json['accessToken'] as String? ?? json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.disabled = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final bool disabled;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class TripDetail {
  TripDetail({
    required this.id,
    required this.riderId,
    required this.serviceId,
    required this.originText,
    required this.destText,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.driverId,
    this.lastLocation,
  });

  final String id;
  final String riderId;
  final String serviceId;
  final String originText;
  final String destText;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? driverId;
  final LocationUpdate? lastLocation;

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    return TripDetail(
      id: json['id'] as String? ?? '',
      riderId: json['riderId'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      originText: json['originText'] as String? ?? '',
      destText: json['destText'] as String? ?? '',
      originLat: (json['originLat'] as num?)?.toDouble(),
      originLng: (json['originLng'] as num?)?.toDouble(),
      destLat: (json['destLat'] as num?)?.toDouble(),
      destLng: (json['destLng'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      driverId: json['driverId'] as String?,
      lastLocation: json['lastLocation'] is Map<String, dynamic>
          ? LocationUpdate.fromJson(
              json['lastLocation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PagedUsers {
  PagedUsers({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<UserProfile> items;
  final int total;
  final int limit;
  final int offset;

  factory PagedUsers.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return PagedUsers(
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(UserProfile.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? itemsJson.length,
      limit: (json['limit'] as num?)?.toInt() ?? itemsJson.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class Promotion {
  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.gradientStart,
    required this.gradientEnd,
    this.imageUrl,
    this.expiresAt,
    this.priority = 0,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String description;
  final String code;
  final String gradientStart;
  final String gradientEnd;
  final String? imageUrl;
  final DateTime? expiresAt;
  final int priority;
  final bool isActive;

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      code: json['code'] as String? ?? '',
      gradientStart: json['gradientStart'] as String? ?? '#0FB7A0',
      gradientEnd: json['gradientEnd'] as String? ?? '#1E9FD7',
      imageUrl: json['imageUrl'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class LocationUpdate {
  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
