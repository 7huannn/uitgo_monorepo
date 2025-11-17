import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/websocket_connector.dart';
import '../../auth/services/auth_service.dart';
import '../models/trip_models.dart';

class TripService {
  TripService._internal();
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;

  final Dio _dio = DioClient().dio;
  final AuthService _auth = AuthService();
  WebSocketChannel? _channel;

  Future<TripDetail> createTrip({
    required String originText,
    required String destText,
    required String serviceId,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  }) async {
    final now = DateTime.now().toUtc();

    if (useMock) {
      return TripDetail(
        id: 'mock-trip-${now.millisecondsSinceEpoch}',
        riderId: 'demo-user',
        serviceId: serviceId,
        originText: originText,
        destText: destText,
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        status: 'requested',
        createdAt: now,
        updatedAt: now,
      );
    }

    try {
      final response = await _dio.post(
        '/v1/trips',
        data: {
          'originText': originText,
          'destText': destText,
          'serviceId': serviceId,
          if (originLat != null) 'originLat': originLat,
          if (originLng != null) 'originLng': originLng,
          if (destLat != null) 'destLat': destLat,
          if (destLng != null) 'destLng': destLng,
        },
      );

      return TripDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 402) {
        throw Exception(
            'Ví UITGo Pay không đủ số dư. Vui lòng nạp thêm để tiếp tục.');
      }
      rethrow;
    }
  }

  Future<PagedTrips> listTrips({
    required String role,
    int limit = 20,
    int offset = 0,
    int? page,
    int? pageSize,
  }) async {
    if (debugListTrips != null) {
      return debugListTrips!(
        role: role,
        limit: limit,
        offset: offset,
        page: page,
        pageSize: pageSize,
      );
    }
    if (useMock) {
      final now = DateTime.now();
      final trips = List.generate(
        5,
        (index) => TripDetail(
          id: 'mock-trip-$index',
          riderId: 'demo-user',
          serviceId: 'UIT-Go',
          originText: 'UIT Campus ${index + 1}',
          destText: 'KTX ${index + 1}',
          status: index % 2 == 0 ? 'completed' : 'cancelled',
          createdAt: now.subtract(Duration(days: index)),
          updatedAt: now.subtract(Duration(days: index)),
        ),
      );
      final slice = trips.skip(offset).take(limit).toList();
      return PagedTrips(
        items: slice,
        total: trips.length,
        limit: limit,
        offset: offset,
      );
    }

    final params = <String, dynamic>{
      'role': role,
    };
    if (page != null && page > 0) {
      params['page'] = page;
      if (pageSize != null && pageSize > 0) {
        params['pageSize'] = pageSize;
      }
    } else {
      params['limit'] = limit;
      params['offset'] = offset;
    }

    final res = await _dio.get('/v1/trips', queryParameters: params);

    return PagedTrips.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TripDetail> fetchTrip(String tripId) async {
    if (useMock) {
      final now = DateTime.now();
      return TripDetail(
        id: tripId,
        riderId: 'demo-user',
        serviceId: 'UIT-Go',
        originText: 'Sảnh A, Đại học UIT',
        destText: 'Ký túc xá Khu B',
        status: 'requested',
        createdAt: now.subtract(const Duration(minutes: 3)),
        updatedAt: now,
        lastLocation: LocationUpdate(
          latitude: 10.8705,
          longitude: 106.8032,
          timestamp: now,
        ),
      );
    }

    final res = await _dio.get('/v1/trips/$tripId');
    return TripDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Stream<TripRealtimeEvent>> connectToTrip(String tripId,
      {String role = 'rider'}) async {
    if (useMock) {
      final controller = StreamController<TripRealtimeEvent>();
      controller.onCancel = controller.close;
      Timer(const Duration(seconds: 2), () {
        controller.add(
          TripRealtimeEvent.fromLocation(
            LocationUpdate(
              latitude: 10.8705,
              longitude: 106.8032,
              timestamp: DateTime.now(),
            ),
          ),
        );
      });
      Timer(const Duration(seconds: 5), () {
        controller.add(TripRealtimeEvent.fromStatus('arriving'));
      });
      return controller.stream;
    }

    await closeChannel();

    final userInfo = await _auth.getUserInfo();
    final userId = userInfo['userId'];
    if (userId == null || userId.trim().isEmpty) {
      throw const AuthException('Vui lòng đăng nhập lại để tiếp tục.');
    }
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Phiên đăng nhập đã hết hạn.');
    }

    final uri = _buildWsUri(
      tripId,
      role,
      userId,
      tokenForQuery: kIsWeb ? token : null,
    );

    final headers = <String, dynamic>{
      if (!kIsWeb) 'Authorization': 'Bearer $token',
    };

    final channel = connectWebSocket(uri, headers: headers);
    _channel = channel;

    return channel.stream.map((event) {
      try {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        if (type == 'location') {
          final payload = data['location'];
          if (payload is Map<String, dynamic>) {
            return TripRealtimeEvent.fromLocation(
              LocationUpdate.fromJson(payload),
            );
          }
          if (data['lat'] != null && data['lng'] != null) {
            return TripRealtimeEvent.fromLocation(
              LocationUpdate.fromJson(
                {
                  'lat': data['lat'],
                  'lng': data['lng'],
                  'timestamp': data['timestamp'],
                },
              ),
            );
          }
        }
        if (type == 'status' && data['status'] != null) {
          return TripRealtimeEvent.fromStatus(data['status'] as String);
        }
      } catch (_) {
        // ignore malformed payloads
      }
      return TripRealtimeEvent.unknown();
    });
  }

  Future<void> closeChannel() async {
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _buildWsUri(String tripId, String role, String userId,
      {String? tokenForQuery}) {
    final baseUri = Uri.parse(apiBase);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final path = baseUri.path.endsWith('/')
        ? '${baseUri.path}v1/trips/$tripId/ws'
        : '${baseUri.path}/v1/trips/$tripId/ws';
    final params = <String, String>{
      'role': role,
      'userId': userId,
    };
    if (tokenForQuery != null && tokenForQuery.isNotEmpty) {
      params['accessToken'] = tokenForQuery;
    }
    return baseUri.replace(
      scheme: scheme,
      path: path,
      queryParameters: params,
    );
  }
}

// Test injection hook
@visibleForTesting
typedef DebugListTripsFn = Future<PagedTrips> Function({
  required String role,
  int limit,
  int offset,
  int? page,
  int? pageSize,
});

@visibleForTesting
DebugListTripsFn? debugListTrips;
