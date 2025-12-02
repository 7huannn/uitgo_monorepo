class WalletEarningPoint {
  const WalletEarningPoint({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  factory WalletEarningPoint.fromJson(Map<String, dynamic> json) {
    return WalletEarningPoint(
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
      };
}

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    this.currency = 'VND',
    this.recentEarnings = const [],
  });

  final double balance;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final String currency;
  final List<WalletEarningPoint> recentEarnings;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final earningsJson = json['recentEarnings'] as List<dynamic>? ?? [];
    return WalletSummary(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      weeklyRevenue: (json['weeklyRevenue'] as num?)?.toDouble() ?? 0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'VND',
      recentEarnings: earningsJson
          .whereType<Map<String, dynamic>>()
          .map(WalletEarningPoint.fromJson)
          .toList(),
    );
  }

  WalletSummary copyWith({
    double? balance,
    double? weeklyRevenue,
    double? monthlyRevenue,
    String? currency,
    List<WalletEarningPoint>? recentEarnings,
  }) {
    return WalletSummary(
      balance: balance ?? this.balance,
      weeklyRevenue: weeklyRevenue ?? this.weeklyRevenue,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      currency: currency ?? this.currency,
      recentEarnings: recentEarnings ?? this.recentEarnings,
    );
  }
}

class WalletTransactionType {
  const WalletTransactionType._(this.value);
  final String value;

  static const income = WalletTransactionType._('income');
  static const payout = WalletTransactionType._('payout');

  static WalletTransactionType from(String? value) {
    switch (value) {
      case 'payout':
        return payout;
      case 'income':
      default:
        return income;
    }
  }

  bool get isIncome => this == income;

  @override
  String toString() => value;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
    this.description,
    this.reference,
    this.currency = 'VND',
  });

  final String id;
  final double amount;
  final WalletTransactionType type;
  final String status;
  final DateTime createdAt;
  final String? description;
  final String? reference;
  final String currency;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: WalletTransactionType.from(json['type'] as String?),
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      currency: json['currency'] as String? ?? 'VND',
    );
  }
}

class WalletTransactionsResult {
  const WalletTransactionsResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<WalletTransaction> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory WalletTransactionsResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return WalletTransactionsResult(
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(),
      total: json['total'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
    );
  }
}
