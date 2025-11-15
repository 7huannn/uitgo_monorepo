import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/models/home_models.dart';
import '../../wallet/models/wallet_transaction.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/state/wallet_notifier.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final WalletService _walletService = WalletService();
  final int _pageSize = 20;

  List<WalletTransactionModel> _transactions = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _topUpLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletNotifier>().refresh();
    });
  }

  Future<void> _loadTransactions({bool refresh = true}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (_loadingMore || !_hasMore) {
      return;
    } else {
      setState(() => _loadingMore = true);
    }

    final nextOffset = refresh ? 0 : _transactions.length;
    try {
      final page = await _walletService.fetchTransactions(
        limit: _pageSize,
        offset: nextOffset,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _transactions = page.items;
        } else {
          _transactions = [..._transactions, ...page.items];
        }
        final total = page.total;
        if (total > 0) {
          _hasMore = (nextOffset + page.items.length) < total;
        } else {
          _hasMore = page.items.length == _pageSize;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _handleTopUp() async {
    final amount = await _promptTopUpAmount();
    if (!mounted || amount == null) return;
    setState(() => _topUpLoading = true);
    try {
      await context.read<WalletNotifier>().topUp(amount);
      await _loadTransactions(refresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nạp ${_formatCurrency(amount)} đ vào ví.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nạp tiền thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _topUpLoading = false);
      }
    }
  }

  Future<int?> _promptTopUpAmount() async {
    final controller = TextEditingController(text: '100000');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập số tiền muốn nạp'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 150000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.replaceAll('.', ''));
              if (value == null || value < 10000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Vui lòng nhập số tiền tối thiểu 10.000đ')),
                );
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví & Thanh toán'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Consumer<WalletNotifier>(
              builder: (context, notifier, _) {
                return _WalletSummaryCard(
                  summary: notifier.summary ??
                      WalletSummary(balance: 0, rewardPoints: 0),
                  refreshing: notifier.refreshing || _topUpLoading,
                  onTopUp: _topUpLoading ? null : _handleTopUp,
                );
              },
            ),
            const SizedBox(height: 20),
            _buildTransactionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSection() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Column(
        children: [
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
          UitPrimaryButton(
            label: 'Thử lại',
            onPressed: () => _loadTransactions(refresh: true),
            expand: false,
          ),
        ],
      );
    }
    if (_transactions.isEmpty) {
      return _EmptyTransactions(onTopUp: _handleTopUp);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử giao dịch',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ..._transactions.map(_buildTransactionTile),
        if (_loadingMore) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ] else if (_hasMore) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _loadTransactions(refresh: false),
            child: const Text('Tải thêm'),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel tx) {
    final isReward = tx.type == WalletTransactionType.reward;
    final amountLabel = isReward
        ? '+${tx.amount} điểm'
        : '${tx.isCredit ? '+' : '-'}${_formatCurrency(tx.amount)} đ';
    final amountColor =
        tx.isCredit ? const Color(0xFF0DB166) : const Color(0xFFE53935);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              tx.isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
          child: Icon(
            _iconForType(tx.type),
            color: amountColor,
          ),
        ),
        title: Text(
          tx.humanLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_formatTimestamp(tx.createdAt)),
        trailing: Text(
          amountLabel,
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  IconData _iconForType(WalletTransactionType type) {
    switch (type) {
      case WalletTransactionType.topup:
        return Icons.arrow_downward_rounded;
      case WalletTransactionType.reward:
        return Icons.stars_rounded;
      case WalletTransactionType.deduction:
        return Icons.arrow_upward_rounded;
    }
  }

  String _formatTimestamp(DateTime time) {
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute • $day/$month';
  }

  String _formatCurrency(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final posFromEnd = digits.length - i - 1;
      if (posFromEnd % 3 == 0 && i != digits.length - 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.summary,
    required this.refreshing,
    required this.onTopUp,
  });

  final WalletSummary summary;
  final bool refreshing;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư ví UITGo Pay',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatCurrency(summary.balance)} đ',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Điểm thưởng hiện có: ${summary.rewardPoints}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            UitPrimaryButton(
              label: 'Nạp thêm',
              loading: refreshing,
              onPressed: onTopUp,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final posFromEnd = digits.length - i - 1;
      if (posFromEnd % 3 == 0 && i != digits.length - 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onTopUp});

  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.receipt_long, size: 56, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Chưa có giao dịch',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bắt đầu trải nghiệm UIT-Go và tích luỹ điểm thưởng ngay hôm nay.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onTopUp,
          child: const Text('Nạp tiền đầu tiên'),
        )
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
