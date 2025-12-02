import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../home/models/home_models.dart';
import '../models/wallet_transaction.dart';

abstract class WalletGateway {
  Future<WalletSummary> fetchSummary();
  Future<WalletSummary> topUp({required int amount});
}

class WalletService implements WalletGateway {
  WalletService._internal();
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  final Dio _dio = DioClient().dio;

  Future<WalletSummary> fetchSummary() async {
    try {
      final response = await _dio.get('/v1/wallet');
      return WalletSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  Future<WalletTransactionPage> fetchTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/v1/wallet/transactions',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return WalletTransactionPage.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  Future<WalletSummary> topUp({required int amount}) async {
    try {
      final response = await _dio.post(
        '/v1/wallet/topup',
        data: {'amount': amount},
      );
      return WalletSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    return error.message ?? 'Đã có lỗi xảy ra';
  }
}
