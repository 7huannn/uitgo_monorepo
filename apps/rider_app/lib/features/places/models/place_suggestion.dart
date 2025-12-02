class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  String get displayName =>
      address?.isNotEmpty == true ? '$name, $address' : name;
}
