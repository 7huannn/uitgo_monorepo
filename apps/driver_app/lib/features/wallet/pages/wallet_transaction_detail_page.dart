import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/wallet_models.dart';

class WalletTransactionDetailArgs {
  const WalletTransactionDetailArgs({required this.transaction});

  final WalletTransaction transaction;
}

class WalletTransactionDetailPage extends StatelessWidget {
  const WalletTransactionDetailPage({super.key, required this.transaction});

  static const routeName = '/wallet/transaction_detail';

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final dateFormatter = DateFormat('HH:mm dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    formatter.format(transaction.amount),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: transaction.type.isIncome
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      transaction.type.isIncome ? 'Thu nhập' : 'Rút tiền',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.status,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DetailRow(
            label: 'Mã giao dịch',
            value: transaction.id,
            icon: Icons.tag,
          ),
          _DetailRow(
            label: 'Thời gian',
            value: dateFormatter.format(transaction.createdAt),
            icon: Icons.schedule,
          ),
          if (transaction.description != null)
            _DetailRow(
              label: 'Nội dung',
              value: transaction.description!,
              icon: Icons.notes,
            ),
          if (transaction.reference != null)
            _DetailRow(
              label: 'Mã tham chiếu',
              value: transaction.reference!,
              icon: Icons.confirmation_number,
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Thông tin giao dịch ví đang sử dụng dữ liệu giả lập. '
                'TODO: Kết nối với API ví thực tế khi backend sẵn sàng.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
