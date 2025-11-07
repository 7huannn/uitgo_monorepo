import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
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
  }) async {
    final now = DateTime.now().toUtc();

    if (useMock) {
      return TripDetail(
        id: 'mock-trip-${now.millisecondsSinceEpoch}',
        riderId: 'demo-user',
        serviceId: serviceId,
        originText: originText,
        destText: destText,
        status: 'requested',
        createdAt: now,
        updatedAt: now,
      );
    }

    final response = await _dio.post(
      '/v1/trips',
      data: {
        'originText': originText,
        'destText': destText,
        'serviceId': serviceId,
      },
    );

    return TripDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PagedTrips> listTrips({
    required String role,
    int limit = 20,
    int offset = 0,
  }) async {
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

    final res = await _dio.get('/v1/trips', queryParameters: {
      'role': role,
      'limit': limit,
      'offset': offset,
    });

    return PagedTrips.fromJson(res.data as Map<String, dynamic>);
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
    final userId = userInfo['userId']?.trim().isNotEmpty == true
        ? userInfo['userId']!
        : 'demo-user';

    final uri = _buildWsUri(tripId, role, userId);

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    return channel.stream.map((event) {
      try {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        if (type == 'location' && data['location'] != null) {
          return TripRealtimeEvent.fromLocation(
            LocationUpdate.fromJson(data['location'] as Map<String, dynamic>),
          );
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

  Uri _buildWsUri(String tripId, String role, String userId) {
    final baseUri = Uri.parse(apiBase);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final path = baseUri.path.endsWith('/')
        ? '${baseUri.path}v1/trips/$tripId/ws'
        : '${baseUri.path}/v1/trips/$tripId/ws';
    return baseUri.replace(
      scheme: scheme,
      path: path,
      queryParameters: {
        'role': role,
        'userId': userId,
      },
    );
  }
}
