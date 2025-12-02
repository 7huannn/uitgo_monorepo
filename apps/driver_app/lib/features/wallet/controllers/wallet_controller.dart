import 'package:flutter/foundation.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class WalletController extends ChangeNotifier {
  WalletController(this._service);

  final WalletService _service;

  WalletSummary? summary;
  List<WalletTransaction> transactions = const [];

  bool loadingSummary = false;
  bool loadingTransactions = false;
  bool loadingMore = false;
  bool refreshing = false;
  bool initialized = false;
  bool _hasMore = true;
  int _offset = 0;

  String? error;

  static const _pageSize = 20;

  Future<void> bootstrap() async {
    await Future.wait([
      loadSummary(),
      loadTransactions(reset: true),
    ]);
    initialized = true;
    notifyListeners();
  }

  Future<void> loadSummary() async {
    loadingSummary = true;
    notifyListeners();
    try {
      summary = await _service.getSummary();
      error = null;
    } catch (e) {
      error = 'Không thể tải thông tin ví tiền';
    } finally {
      loadingSummary = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactions({bool reset = false}) async {
    if (reset) {
      loadingTransactions = true;
      _hasMore = true;
      _offset = 0;
      transactions = const [];
      notifyListeners();
    } else {
      if (!_hasMore || loadingMore) {
        return;
      }
      loadingMore = true;
      notifyListeners();
    }

    try {
      final page = await _service.listTransactions(
        limit: _pageSize,
        offset: _offset,
      );
      error = null;
      if (reset) {
        transactions = page.items;
      } else {
        transactions = [...transactions, ...page.items];
      }
      _offset = page.offset + page.items.length;
      _hasMore = page.hasMore;
    } catch (e) {
      error = 'Không thể tải giao dịch ví';
    } finally {
      if (reset) {
        loadingTransactions = false;
      } else {
        loadingMore = false;
      }
      notifyListeners();
    }
  }

  bool get canLoadMore => _hasMore && !loadingMore;

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      await Future.wait([
        loadSummary(),
        loadTransactions(reset: true),
      ]);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}
