import 'package:dio/dio.dart';

import '../../../core/config/config.dart';
import '../../../core/network/dio_client.dart';
import '../models/wallet_models.dart';

/// Handles wallet specific API calls. Replace the mocked responses with
/// the backend wallet endpoints when they become available.
class WalletService {
  WalletService({Dio? dio}) : _dio = dio ?? DioClient().dio;

  final Dio _dio;

  Future<WalletSummary> getSummary() async {
    if (useMock) {
      final earnings = List.generate(
        7,
        (index) => WalletEarningPoint(
          label: 'T${index + 2}',
          amount: 120000 + (index * 18000),
        ),
      );
      return WalletSummary(
        balance: 2750000,
        weeklyRevenue: 1680000,
        monthlyRevenue: 7250000,
        recentEarnings: earnings,
      );
    }

    final response = await _dio.get('/v1/wallet/summary');
    return WalletSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WalletTransactionsResult> listTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    if (useMock) {
      final now = DateTime.now();
      final items = List.generate(
        limit,
        (i) {
          final id = offset + i + 1;
          return WalletTransaction(
            id: 'mock-tx-$id',
            amount: 75000 + (i * 12500),
            type: id.isEven
                ? WalletTransactionType.income
                : WalletTransactionType.payout,
            status: id.isEven ? 'Hoàn tất' : 'Đang xử lý',
            description:
                id.isEven ? 'Thu nhập chuyến #$id' : 'Rút tiền ví #$id',
            createdAt: now.subtract(Duration(hours: id * 3)),
          );
        },
      );
      return WalletTransactionsResult(
        items: items,
        total: offset == 0 ? limit * 3 : limit * 3 - offset,
        limit: limit,
        offset: offset,
      );
    }

    final response = await _dio.get(
      '/v1/wallet/transactions',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    return WalletTransactionsResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
