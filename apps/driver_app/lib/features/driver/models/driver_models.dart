enum DriverAvailability { online, offline }

DriverAvailability driverAvailabilityFromString(String? value) {
  switch (value) {
    case 'online':
      return DriverAvailability.online;
    default:
      return DriverAvailability.offline;
  }
}

class DriverVehicle {
  const DriverVehicle({
    required this.make,
    required this.model,
    required this.color,
    required this.plateNumber,
  });

  final String make;
  final String model;
  final String color;
  final String plateNumber;

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    return DriverVehicle(
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
    );
  }
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.licenseNumber,
    required this.rating,
    required this.availability,
    this.vehicle,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String licenseNumber;
  final double rating;
  final DriverAvailability availability;
  final DriverVehicle? vehicle;

  DriverProfile copyWith({
    DriverAvailability? availability,
  }) {
    return DriverProfile(
      id: id,
      userId: userId,
      fullName: fullName,
      phone: phone,
      licenseNumber: licenseNumber,
      rating: rating,
      availability: availability ?? this.availability,
      vehicle: vehicle,
    );
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    final statusPayload = json['status'];
    final availability = () {
      if (statusPayload is Map<String, dynamic>) {
        return driverAvailabilityFromString(statusPayload['availability'] as String?);
      }
      return driverAvailabilityFromString(statusPayload as String?);
    }();

    return DriverProfile(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      licenseNumber: json['licenseNumber'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      availability: availability,
      vehicle: json['vehicle'] is Map<String, dynamic>
          ? DriverVehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null,
    );
  }
}
