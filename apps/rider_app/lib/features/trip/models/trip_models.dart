class TripDetail {
  TripDetail({
    required this.id,
    required this.riderId,
    required this.serviceId,
    required this.originText,
    required this.destText,
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
      status: json['status'] as String? ?? 'requested',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      driverId: json['driverId'] as String?,
      lastLocation: json['lastLocation'] != null
          ? LocationUpdate.fromJson(
              json['lastLocation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LocationUpdate {
  LocationUpdate({
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

class TripRealtimeEvent {
  TripRealtimeEvent._({
    this.type,
    this.status,
    this.location,
  });

  factory TripRealtimeEvent.unknown() => TripRealtimeEvent._();

  factory TripRealtimeEvent.fromStatus(String status) {
    return TripRealtimeEvent._(
      type: RealtimeEventType.status,
      status: status,
    );
  }

  factory TripRealtimeEvent.fromLocation(LocationUpdate update) {
    return TripRealtimeEvent._(
      type: RealtimeEventType.location,
      location: update,
    );
  }

  final RealtimeEventType? type;
  final String? status;
  final LocationUpdate? location;
}

enum RealtimeEventType { status, location }
