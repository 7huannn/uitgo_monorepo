import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/wallet_controller.dart';
import '../models/wallet_models.dart';
import '../widgets/wallet_transaction_tile.dart';
import 'wallet_route_args.dart';
import 'wallet_transaction_detail_page.dart';
import 'wallet_transactions_page.dart';

class WalletOverviewPage extends StatefulWidget {
  const WalletOverviewPage({super.key});

  static const routeName = '/wallet';

  @override
  State<WalletOverviewPage> createState() => _WalletOverviewPageState();
}

class _WalletOverviewPageState extends State<WalletOverviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<WalletController>();
      if (!controller.initialized) {
        controller.bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WalletController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví của tôi'),
        actions: [
          IconButton(
            tooltip: 'Xem giao dịch',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => _openTransactions(context, controller),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (controller.error != null) ...[
              _ErrorBanner(message: controller.error!),
              const SizedBox(height: 16),
            ],
            _WalletSummaryCard(
              summary: controller.summary,
              loading: controller.loadingSummary && controller.summary == null,
              onWithdraw: () => _showWithdrawDialog(context),
            ),
            const SizedBox(height: 16),
            _RevenueGrid(summary: controller.summary),
            const SizedBox(height: 24),
            _EarningsChart(
                points: controller.summary?.recentEarnings ?? const []),
            const SizedBox(height: 24),
            _RecentTransactionsSection(controller: controller),
          ],
        ),
      ),
    );
  }

  void _openTransactions(BuildContext context, WalletController controller) {
    Navigator.pushNamed(
      context,
      WalletTransactionsPage.routeName,
      arguments: WalletRouteControllerArgs(controller: controller),
    );
  }

  Future<void> _showWithdrawDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rút tiền sắp ra mắt'),
        content: const Text(
          'Chức năng rút tiền đang được hoàn thiện. '
          'UIT-Go sẽ thông báo ngay khi có thể sử dụng.',
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.summary,
    required this.loading,
    required this.onWithdraw,
  });

  final WalletSummary? summary;
  final bool loading;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số dư hiện tại',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Text(
                    formatter.format(summary?.balance ?? 0),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
            const SizedBox(height: 24),
            UitPrimaryButton(
              label: 'Rút tiền',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: onWithdraw,
            ),
            const SizedBox(height: 8),
            Text(
              'Tính năng rút tiền sẽ được kết nối với API thực tế trong tương lai.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueGrid extends StatelessWidget {
  const _RevenueGrid({required this.summary});

  final WalletSummary? summary;

  @override
  Widget build(BuildContext context) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Doanh thu tuần',
            value: formatter.format(summary?.weeklyRevenue ?? 0),
            icon: Icons.calendar_view_week,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Doanh thu tháng',
            value: formatter.format(summary?.monthlyRevenue ?? 0),
            icon: Icons.calendar_month,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }
}

class _EarningsChart extends StatelessWidget {
  const _EarningsChart({required this.points});

  final List<WalletEarningPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Chưa có dữ liệu thống kê gần đây.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final max = points.map((point) => point.amount).reduce(
          (value, element) => value > element ? value : element,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thu nhập 7 ngày gần nhất',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((point) {
                final double ratio = max == 0 ? 0 : point.amount / max;
                final double height = (ratio * 140).clamp(12, 140).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          height: height,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          point.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final recent = controller.transactions.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Giao dịch gần đây',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  WalletTransactionsPage.routeName,
                  arguments: WalletRouteControllerArgs(controller: controller),
                );
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.loadingTransactions && recent.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (recent.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Chưa có giao dịch.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          Column(
            children: recent
                .map(
                  (tx) => WalletTransactionTile(
                    transaction: tx,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        WalletTransactionDetailPage.routeName,
                        arguments: WalletTransactionDetailArgs(transaction: tx),
                      );
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
