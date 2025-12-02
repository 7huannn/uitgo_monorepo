import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';

class RouteOverview {
  const RouteOverview({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polylinePoints,
    this.steps = const [],
    this.isApproximate = false,
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> polylinePoints;
  final List<RouteStep> steps;
  final bool isApproximate;

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedEta {
    final minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h${mins.toString().padLeft(2, '0')}';
    }
    return '$minutes phút';
  }
}

class RouteStep {
  const RouteStep({
    required this.name,
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.location,
  });

  final String name;
  final String instruction;
  final LatLng? location;
  final double distanceMeters;
  final double durationSeconds;
}

class RoutingService {
  RoutingService._internal();
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;

  final Dio _dio = DioClient().dio;

  Future<RouteOverview?> fetchRoute(LatLng from, LatLng to) async {
    if (useMock) {
      return RouteOverview(
        distanceMeters: 5200,
        durationSeconds: 900,
        polylinePoints: [from, to],
        steps: const [],
      );
    }

    try {
      final endpoint = routesEndpoint.isEmpty
          ? '/routes'
          : (routesEndpoint.startsWith('/') ? routesEndpoint : '/$routesEndpoint');
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'origin': {
            'lat': from.latitude,
            'lng': from.longitude,
          },
          'destination': {
            'lat': to.latitude,
            'lng': to.longitude,
          },
        },
      );
      if (response.statusCode != 200) {
        return _buildFallbackRoute(from, to);
      }
      final data = response.data ?? <String, dynamic>{};
      final distance = (data['distance'] as num?)?.toDouble();
      final duration = (data['duration'] as num?)?.toDouble();
      final coords = data['coordinates'] as List<dynamic>? ?? const [];
      final points = coords
          .whereType<List<dynamic>>()
          .where((pair) => pair.length >= 2)
          .map((pair) => LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();
      final steps = _parseSteps(data['steps']);
      if (distance == null || duration == null || points.isEmpty) {
        return _buildFallbackRoute(from, to);
      }
      return RouteOverview(
        distanceMeters: distance,
        durationSeconds: duration,
        polylinePoints: points,
        steps: steps,
      );
    } on DioException {
      final direct = await _fetchDirectOsrm(from, to);
      return direct ?? _buildFallbackRoute(from, to);
    }
  }

  RouteOverview _buildFallbackRoute(LatLng from, LatLng to) {
    final rawMeters = const Distance().as(LengthUnit.Meter, from, to);
    final meters = rawMeters.clamp(0.0, double.infinity).toDouble();
    const double avgSpeedMetersPerSecond = 25 * 1000 / 3600; // 25km/h
    final effectiveSpeed =
        avgSpeedMetersPerSecond <= 0 ? 1.0 : avgSpeedMetersPerSecond;
    final duration = meters == 0 ? 0.0 : meters / effectiveSpeed;
    final polyline = [from, to];
    return RouteOverview(
      distanceMeters: meters,
      durationSeconds: duration,
      polylinePoints: polyline,
      isApproximate: true,
      steps: const [],
    );
  }

  List<RouteStep> _parseSteps(dynamic rawSteps) {
    final steps = (rawSteps as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((step) {
      final name = (step['name'] as String?) ?? '';
      final instruction = (step['instruction'] as String?) ?? '';
      final location = step['location'] as List<dynamic>? ?? const [];
      final distance = (step['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (step['duration'] as num?)?.toDouble() ?? 0.0;
      LatLng? parsedLocation;
      if (location.length >= 2) {
        final lng = (location[0] as num).toDouble();
        final lat = (location[1] as num).toDouble();
        parsedLocation = LatLng(lat, lng);
      }
      return RouteStep(
        name: name,
        instruction: instruction,
        location: parsedLocation,
        distanceMeters: distance,
        durationSeconds: duration,
      );
    }).toList();
    return steps;
  }

  Future<RouteOverview?> _fetchDirectOsrm(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
              '$routingBase/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}')
          .replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
      });
      final response = await _dio.getUri(uri);
      if (response.statusCode != 200) {
        return null;
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final routes = data['routes'] as List<dynamic>? ?? [];
      if (routes.isEmpty || routes.first is! Map<String, dynamic>) {
        return null;
      }
      final first = routes.first as Map<String, dynamic>;
      final distance = (first['distance'] as num?)?.toDouble();
      final duration = (first['duration'] as num?)?.toDouble();
      final geometry = first['geometry'] as Map<String, dynamic>? ?? {};
      final coords = geometry['coordinates'] as List<dynamic>? ?? [];
      final points = coords
          .whereType<List<dynamic>>()
          .where((pair) => pair.length >= 2)
          .map((pair) => LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();
      if (distance == null || duration == null || points.isEmpty) {
        return null;
      }
      return RouteOverview(
        distanceMeters: distance,
        durationSeconds: duration,
        polylinePoints: points,
        steps: const [],
      );
    } on DioException {
      return null;
    }
  }
}
