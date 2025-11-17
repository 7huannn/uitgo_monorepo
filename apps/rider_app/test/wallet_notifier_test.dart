import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/features/home/models/home_models.dart';
import 'package:rider_app/features/wallet/services/wallet_service.dart';
import 'package:rider_app/features/wallet/state/wallet_notifier.dart';

void main() {
  group('WalletNotifier', () {
    test('refresh toggles refreshing flag and updates summary', () async {
      final service = _FakeWalletService(
        summary: WalletSummary(balance: 50000, rewardPoints: 10),
      );
      final notifier = WalletNotifier(service: service);
      var changeCount = 0;
      notifier.addListener(() => changeCount++);

      final summary = await notifier.refresh();
      expect(summary.balance, 50000);
      expect(notifier.summary?.balance, 50000);
      expect(notifier.refreshing, isFalse);
      expect(changeCount, greaterThanOrEqualTo(2));
    });

    test('topUp applies amount and notifies listeners', () async {
      final service = _FakeWalletService(
        summary: WalletSummary(balance: 10000, rewardPoints: 5),
      );
      final notifier = WalletNotifier(service: service);
      await notifier.refresh();

      await notifier.topUp(5000);
      expect(notifier.summary?.balance, 15000);
      expect(service.topUpCalls, 1);
    });
  });
}

class _FakeWalletService implements WalletGateway {
  _FakeWalletService({required WalletSummary summary}) : _summary = summary;

  WalletSummary _summary;
  int topUpCalls = 0;

  @override
  Future<WalletSummary> fetchSummary() async {
    return _summary;
  }

  @override
  Future<WalletSummary> topUp({required int amount}) async {
    topUpCalls += 1;
    _summary = WalletSummary(
      balance: _summary.balance + amount,
      rewardPoints: _summary.rewardPoints,
    );
    return _summary;
  }
}
