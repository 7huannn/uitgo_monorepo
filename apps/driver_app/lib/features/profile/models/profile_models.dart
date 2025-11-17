class DriverProfileUpdateRequest {
  const DriverProfileUpdateRequest({
    required this.fullName,
    required this.phone,
    required this.licensePlate,
    required this.vehicleType,
    this.avatarFilePath,
  });

  final String fullName;
  final String phone;
  final String licensePlate;
  final String vehicleType;
  final String? avatarFilePath;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'fullName': fullName,
      'phone': phone,
      'licenseNumber': licensePlate,
      'vehicleType': vehicleType,
    };
    if (avatarFilePath != null && avatarFilePath!.isNotEmpty) {
      payload['avatar'] = avatarFilePath;
    }
    return payload;
  }
}
