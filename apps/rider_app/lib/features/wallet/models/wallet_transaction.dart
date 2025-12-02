enum WalletTransactionType { topup, reward, deduction }

class WalletTransactionModel {
  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final WalletTransactionType type;
  final int amount;
  final DateTime createdAt;

  bool get isCredit => type != WalletTransactionType.deduction;

  String get humanLabel {
    switch (type) {
      case WalletTransactionType.topup:
        return 'Nạp UITGo Pay';
      case WalletTransactionType.reward:
        return 'Thưởng hoàn tất chuyến';
      case WalletTransactionType.deduction:
        return 'Thanh toán chuyến đi';
    }
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? '').toLowerCase();
    final type = WalletTransactionType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => WalletTransactionType.deduction,
    );
    return WalletTransactionModel(
      id: json['id'] as String? ?? '',
      type: type,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class WalletTransactionPage {
  WalletTransactionPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<WalletTransactionModel> items;
  final int total;
  final int limit;
  final int offset;

  factory WalletTransactionPage.fromJson(Map<String, dynamic> json) {
    final data = json['items'] as List<dynamic>? ?? [];
    return WalletTransactionPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(WalletTransactionModel.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
