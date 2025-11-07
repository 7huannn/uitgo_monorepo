class TripStatus {
  const TripStatus._(this.value);
  final String value;

  static const requested = TripStatus._('requested');
  static const accepted = TripStatus._('accepted');
  static const arriving = TripStatus._('arriving');
  static const inRide = TripStatus._('in_ride');
  static const completed = TripStatus._('completed');
  static const cancelled = TripStatus._('cancelled');

  static TripStatus from(String? value) {
    switch (value) {
      case 'accepted':
        return accepted;
      case 'arriving':
        return arriving;
      case 'in_ride':
        return inRide;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      default:
        return requested;
    }
  }

  @override
  String toString() => value;
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
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'timestamp': timestamp.toIso8601String(),
      };
}

class TripDetail {
  const TripDetail({
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
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? driverId;
  final LocationUpdate? lastLocation;

  TripDetail copyWith({
    TripStatus? status,
    LocationUpdate? lastLocation,
  }) {
    return TripDetail(
      id: id,
      riderId: riderId,
      serviceId: serviceId,
      originText: originText,
      destText: destText,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      driverId: driverId,
      lastLocation: lastLocation ?? this.lastLocation,
    );
  }

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    return TripDetail(
      id: json['id'] as String? ?? '',
      riderId: json['riderId'] as String? ?? '',
      driverId: json['driverId'] as String?,
      serviceId: json['serviceId'] as String? ?? '',
      originText: json['originText'] as String? ?? '',
      destText: json['destText'] as String? ?? '',
      status: TripStatus.from(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      lastLocation: json['lastLocation'] is Map<String, dynamic>
          ? LocationUpdate.fromJson(json['lastLocation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PagedTrips {
  const PagedTrips({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<TripDetail> items;
  final int total;
  final int limit;
  final int offset;

  factory PagedTrips.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return PagedTrips(
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(TripDetail.fromJson)
          .toList(),
      total: json['total'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

class TripRealtimeEvent {
  const TripRealtimeEvent.location(this.location)
      : status = null,
        type = 'location';
  const TripRealtimeEvent.status(this.status)
      : location = null,
        type = 'status';

  final String type;
  final LocationUpdate? location;
  final TripStatus? status;

  factory TripRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    if (type == 'location' && json['location'] is Map<String, dynamic>) {
      return TripRealtimeEvent.location(
        LocationUpdate.fromJson(json['location'] as Map<String, dynamic>),
      );
    }
    if (type == 'location' && json['lat'] != null && json['lng'] != null) {
      return TripRealtimeEvent.location(
        LocationUpdate(
          latitude: (json['lat'] as num).toDouble(),
          longitude: (json['lng'] as num).toDouble(),
          timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        ),
      );
    }
    if (type == 'status' && json['status'] is String) {
      return TripRealtimeEvent.status(TripStatus.from(json['status'] as String?));
    }
    return TripRealtimeEvent.status(null);
  }
}
