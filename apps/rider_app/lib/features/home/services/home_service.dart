import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../models/home_models.dart';

class HomeService {
  HomeService._internal();
  static final HomeService _instance = HomeService._internal();
  factory HomeService() => _instance;

  final Dio _dio = DioClient().dio;

  Future<WalletSummary> fetchWallet() async {
    final response = await _dio.get('/wallet');
    return WalletSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SavedPlaceModel>> fetchSavedPlaces() async {
    final response = await _dio.get('/saved_places');
    final data = response.data as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SavedPlaceModel.fromJson)
        .toList();
  }

  Future<SavedPlaceModel> createSavedPlace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.post(
      '/saved_places',
      data: {
        'name': name,
        'address': address,
        'lat': latitude,
        'lng': longitude,
      },
    );
    return SavedPlaceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSavedPlace(String id) async {
    await _dio.delete('/saved_places/$id');
  }

  Future<List<PromotionBanner>> fetchPromotions() async {
    final response = await _dio.get('/promotions');
    final data = response.data as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PromotionBanner.fromJson)
        .toList();
  }

  Future<List<HomeNewsItem>> fetchNews({int limit = 5}) async {
    final response = await _dio.get('/news', queryParameters: {'limit': limit});
    final data = response.data as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(HomeNewsItem.fromJson)
        .toList();
  }
}
