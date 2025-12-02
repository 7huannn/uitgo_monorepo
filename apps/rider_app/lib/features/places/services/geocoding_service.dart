import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config.dart';
import '../models/place_suggestion.dart';

class GeocodingService {
  GeocodingService._internal();
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;

  final Dio _photonDio = Dio(
    BaseOptions(
      baseUrl: 'https://photon.komoot.io',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: const {
        Headers.acceptHeader: 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  )
    ..interceptors.clear()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.remove('Authorization');
          options.headers.remove('authorization');
          handler.next(options);
        },
      ),
    );

  final Dio _nominatimDio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: const {
        Headers.acceptHeader: 'application/json',
        'User-Agent': 'uitgo-rider/1.0 (contact: support@uitgo.local)',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  )..interceptors.clear();

  Future<List<PlaceSuggestion>> search(
    String rawQuery, {
    LatLng? proximity,
  }) async {
    // Test override
    if (debugSearch != null) {
      return debugSearch!(rawQuery, proximity: proximity);
    }
    final query = rawQuery.trim();
    if (query.length < 2) return const [];
    if (useMock) {
      return [
        const PlaceSuggestion(
          name: 'UIT Campus A',
          latitude: 10.8705,
          longitude: 106.8032,
          address: 'Khu phố 6, TP Thủ Đức',
        ),
      ];
    }

    final photonResults =
        await _fetchPhoton(query, proximity: proximity);
    if (photonResults.isNotEmpty) {
      return photonResults;
    }
    if (useNominatimFallback) {
      return _fetchNominatim(query, proximity: proximity);
    }
    return const [];
  }

  Future<List<PlaceSuggestion>> _fetchPhoton(
    String query, {
    LatLng? proximity,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': '5',
      'lang': _photonLang('vi'),
    };
    if (proximity != null) {
      params['lat'] = '${proximity.latitude}';
      params['lon'] = '${proximity.longitude}';
    }
    final uri = Uri.https('photon.komoot.io', '/api', params);
    try {
      final response = await _photonDio.getUri(uri);
      debugPrint(
          '[Photon] ${response.requestOptions.uri} -> ${response.statusCode}');
      if (response.statusCode == 200 &&
          response.data is Map<String, dynamic>) {
        return _parsePhoton(response.data as Map<String, dynamic>);
      }
    } catch (error) {
      debugPrint('[Photon] error: $error');
    }
    return const [];
  }

  String _photonLang(String? requested) {
    const allowed = {'default', 'en', 'de', 'fr'};
    final normalized = requested?.toLowerCase();
    if (normalized == null || !allowed.contains(normalized)) {
      return 'en';
    }
    return normalized;
  }

  Future<List<PlaceSuggestion>> _fetchNominatim(
    String query, {
    LatLng? proximity,
  }) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '5',
      'accept-language': 'vi',
    };
    if (proximity != null) {
      params['viewbox'] =
          '${proximity.longitude - 0.1},${proximity.latitude + 0.1},'
          '${proximity.longitude + 0.1},${proximity.latitude - 0.1}';
      params['bounded'] = '1';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    try {
      final response = await _nominatimDio.getUri(uri);
      debugPrint('[Nominatim] ${response.requestOptions.uri} '
          '-> ${response.statusCode}');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => PlaceSuggestion(
                name:
                    item['display_name'] as String? ?? 'Vị trí không tên',
                latitude:
                    double.tryParse(item['lat']?.toString() ?? '') ?? 0,
                longitude:
                    double.tryParse(item['lon']?.toString() ?? '') ?? 0,
                address: item['display_name'] as String?,
              ),
            )
            .where((place) =>
                place.latitude != 0 && place.longitude != 0)
            .toList();
      }
    } catch (error) {
      debugPrint('[Nominatim] error: $error');
    }
    return const [];
  }

  List<PlaceSuggestion> _parsePhoton(Map<String, dynamic> json) {
    final features = json['features'] as List<dynamic>? ?? [];
    return features
        .whereType<Map<String, dynamic>>()
        .map((feature) {
          final props =
              feature['properties'] as Map<String, dynamic>? ?? {};
          final geometry =
              feature['geometry'] as Map<String, dynamic>? ?? {};
          final coordinates =
              geometry['coordinates'] as List<dynamic>? ?? [];
          if (coordinates.length < 2) return null;
          final name = props['name'] as String? ?? 'Vị trí không tên';
          final street = props['street'] as String?;
          final house = props['housenumber'] as String?;
          final city = props['city'] as String?;
          final state = props['state'] as String?;
          final buffer = [
            if (street?.isNotEmpty == true) street,
            if (house?.isNotEmpty == true) house,
            if (city?.isNotEmpty == true) city,
            if (state?.isNotEmpty == true) state,
          ].join(', ');
          return PlaceSuggestion(
            name: name,
            latitude: (coordinates[1] as num).toDouble(),
            longitude: (coordinates[0] as num).toDouble(),
            address: buffer.isEmpty ? null : buffer,
          );
        })
        .whereType<PlaceSuggestion>()
        .toList();
  }
}

// Test injection hooks
@visibleForTesting
typedef DebugSearchFn = Future<List<PlaceSuggestion>> Function(
  String rawQuery, {
  LatLng? proximity,
});

@visibleForTesting
DebugSearchFn? debugSearch;
