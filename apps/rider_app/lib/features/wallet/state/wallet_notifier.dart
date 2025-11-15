import 'package:flutter/foundation.dart';

import '../../home/models/home_models.dart';
import '../services/wallet_service.dart';

class WalletNotifier extends ChangeNotifier {
  WalletNotifier({WalletService? service})
      : _service = service ?? WalletService();

  final WalletService _service;

  WalletSummary? _summary;
  bool _refreshing = false;

  WalletSummary? get summary => _summary;
  bool get refreshing => _refreshing;

  void replace(WalletSummary summary) {
    _summary = summary;
    notifyListeners();
  }

  Future<WalletSummary> refresh() async {
    _refreshing = true;
    notifyListeners();
    try {
      final latest = await _service.fetchSummary();
      _summary = latest;
      return latest;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<WalletSummary> topUp(int amount) async {
    final summary = await _service.topUp(amount: amount);
    _summary = summary;
    notifyListeners();
    return summary;
  }
}
