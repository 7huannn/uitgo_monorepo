import 'package:dio/dio.dart';
import 'package:driver_app/features/wallet/controllers/wallet_controller.dart';
import 'package:driver_app/features/wallet/models/wallet_models.dart';
import 'package:driver_app/features/wallet/pages/wallet_overview_page.dart';
import 'package:driver_app/features/wallet/pages/wallet_transactions_page.dart';
import 'package:driver_app/features/wallet/services/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('Wallet pages', () {
    testWidgets('WalletOverviewPage renders summary and recent transactions',
        (tester) async {
      final controller = WalletController(_fakeService());
      addTearDown(controller.dispose);
      await controller.bootstrap();
      expect(controller.transactions, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<WalletController>.value(
            value: controller,
            child: const WalletOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Số dư hiện tại'), findsOneWidget);
      expect(
        find.textContaining('Chuyến 1',
            findRichText: true, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Chuyến 2',
            findRichText: true, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('WalletTransactionsPage lists transactions', (tester) async {
      final controller = WalletController(_fakeService());
      addTearDown(controller.dispose);
      await controller.bootstrap();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<WalletController>.value(
            value: controller,
            child: const WalletTransactionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch sử giao dịch'), findsOneWidget);
      expect(find.textContaining('Chuyến 1'), findsOneWidget);
      expect(find.textContaining('Chuyến 2'), findsOneWidget);
    });
  });
}

WalletService _fakeService() {
  final summary = WalletSummary(
    balance: 2500000,
    weeklyRevenue: 840000,
    monthlyRevenue: 5400000,
    recentEarnings: const [
      WalletEarningPoint(label: 'T2', amount: 120000),
      WalletEarningPoint(label: 'T3', amount: 180000),
    ],
  );
  final transactions = [
    WalletTransaction(
      id: 'tx-1',
      amount: 125000,
      type: WalletTransactionType.income,
      status: 'Hoàn tất',
      description: 'Chuyến 1',
      createdAt: DateTime(2024, 7, 1, 8),
    ),
    WalletTransaction(
      id: 'tx-2',
      amount: 95000,
      type: WalletTransactionType.income,
      status: 'Hoàn tất',
      description: 'Chuyến 2',
      createdAt: DateTime(2024, 7, 1, 9),
    ),
  ];
  return _StubWalletService(summary, transactions);
}

class _StubWalletService extends WalletService {
  _StubWalletService(this._summary, this._transactions) : super(dio: Dio());

  final WalletSummary _summary;
  final List<WalletTransaction> _transactions;

  @override
  Future<WalletSummary> getSummary() async => _summary;

  @override
  Future<WalletTransactionsResult> listTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    final slice = _transactions.skip(offset).take(limit).toList();
    return WalletTransactionsResult(
      items: slice,
      total: _transactions.length,
      limit: limit,
      offset: offset,
    );
  }
}
