import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:driver_app/features/wallet/models/wallet_models.dart';
import 'package:driver_app/features/wallet/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletService', () {
    test('getSummary parses API payload', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _StubAdapter((options) {
        captured = options;
        return _StubResponse(
          data: {
            'balance': 3200000,
            'weeklyRevenue': 1500000,
            'monthlyRevenue': 6200000,
            'recentEarnings': [
              {'label': 'T2', 'amount': 350000},
              {'label': 'T3', 'amount': 210000},
            ],
          },
        );
      });

      final service = WalletService(dio: dio);
      final summary = await service.getSummary();

      expect(captured?.uri.path, '/v1/wallet/summary');
      expect(summary.balance, 3200000);
      expect(summary.weeklyRevenue, 1500000);
      expect(summary.recentEarnings, hasLength(2));
    });

    test('listTransactions returns page with provided query parameters',
        () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _StubAdapter((options) {
        captured = options;
        return _StubResponse(
          data: {
            'items': [
              {
                'id': 'tx-1',
                'amount': 45000,
                'type': 'income',
                'status': 'done',
                'createdAt': DateTime(2024, 7, 1, 8).toIso8601String(),
                'description': 'Chuyến A',
              },
              {
                'id': 'tx-2',
                'amount': 12000,
                'type': 'payout',
                'status': 'pending',
                'createdAt': DateTime(2024, 7, 1, 9).toIso8601String(),
              },
            ],
            'total': 5,
            'limit': options.queryParameters['limit'],
            'offset': options.queryParameters['offset'],
          },
        );
      });

      final service = WalletService(dio: dio);
      final page = await service.listTransactions(limit: 2, offset: 0);

      expect(captured?.queryParameters['limit'], 2);
      expect(captured?.queryParameters['offset'], 0);
      expect(page.items, hasLength(2));
      expect(page.items.first.type, WalletTransactionType.income);
      expect(page.hasMore, isTrue);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final _StubResponse Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StubResponse {
  const _StubResponse({
    required this.data,
    this.statusCode = 200,
  });

  final Object data;
  final int statusCode;
}
