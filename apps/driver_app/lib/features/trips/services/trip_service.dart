import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../models/trip_models.dart';

class TripService {
  TripService._internal();
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;

  final Dio _dio = DioClient().dio;

  Future<PagedTrips> listAssigned({int limit = 20, int offset = 0}) async {
    if (useMock) {
      final now = DateTime.now();
      final trips = List.generate(
        3,
        (i) => TripDetail(
          id: 'mock-trip-$i',
          riderId: 'rider-$i',
          serviceId: 'UIT-Bike',
          originText: 'UIT Campus A${i + 1}',
          destText: 'KTX Zone ${i + 1}',
          originLat: 10.8701 + i * 0.001,
          originLng: 106.803 + i * 0.001,
          destLat: 10.869 + i * 0.001,
          destLng: 106.815 + i * 0.001,
          status: i == 0 ? TripStatus.requested : TripStatus.arriving,
          createdAt: now.subtract(Duration(minutes: i * 5)),
          updatedAt: now,
        ),
      );
      return PagedTrips(
        items: trips,
        total: trips.length,
        limit: trips.length,
        offset: 0,
      );
    }

    final res = await _dio.get('/v1/trips', queryParameters: {
      'role': 'driver',
      'limit': limit,
      'offset': offset,
    });
    return PagedTrips.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TripDetail> fetchTrip(String tripId) async {
    if (useMock) {
      final now = DateTime.now();
      return TripDetail(
        id: tripId,
        riderId: 'rider-1',
        serviceId: 'UIT-Bike',
        originText: 'UIT Campus A',
        destText: 'Dormitory',
        originLat: 10.8702,
        originLng: 106.8033,
        destLat: 10.8788,
        destLng: 106.8065,
        status: TripStatus.requested,
        createdAt: now.subtract(const Duration(minutes: 2)),
        updatedAt: now,
      );
    }
    final res = await _dio.get('/v1/trips/$tripId');
    return TripDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> acceptTrip(String tripId) async {
    if (useMock) return;
    await _dio.post('/v1/trips/$tripId/accept');
  }

  Future<void> declineTrip(String tripId) async {
    if (useMock) return;
    await _dio.post('/v1/trips/$tripId/decline');
  }

  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    if (useMock) return;
    await _dio.post('/v1/trips/$tripId/status', data: {
      'status': status.value,
    });
  }
}
