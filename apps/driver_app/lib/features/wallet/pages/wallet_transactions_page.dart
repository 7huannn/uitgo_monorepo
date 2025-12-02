import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/wallet_controller.dart';
import '../widgets/wallet_transaction_tile.dart';
import 'wallet_transaction_detail_page.dart';

class WalletTransactionsPage extends StatefulWidget {
  const WalletTransactionsPage({super.key});

  static const routeName = '/wallet/transactions';

  @override
  State<WalletTransactionsPage> createState() => _WalletTransactionsPageState();
}

class _WalletTransactionsPageState extends State<WalletTransactionsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<WalletController>();
      if (!controller.initialized) {
        controller.bootstrap();
      } else if (controller.transactions.isEmpty &&
          !controller.loadingTransactions) {
        controller.loadTransactions(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = context.read<WalletController>();
    if (!controller.canLoadMore) return;
    if (_scrollController.position.extentAfter < 360 &&
        !controller.loadingMore) {
      controller.loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WalletController>();
    final loading =
        controller.loadingTransactions && controller.transactions.isEmpty;
    final additionalRows = 1 + (controller.error != null ? 1 : 0);
    final itemCount = controller.transactions.length + additionalRows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (controller.error != null && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ErrorBanner(message: controller.error!),
                    );
                  }
                  final adjustedIndex =
                      controller.error == null ? index : index - 1;
                  if (adjustedIndex >= controller.transactions.length) {
                    return _LoadMoreIndicator(controller: controller);
                  }
                  final tx = controller.transactions[adjustedIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WalletTransactionTile(
                      transaction: tx,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          WalletTransactionDetailPage.routeName,
                          arguments:
                              WalletTransactionDetailArgs(transaction: tx),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.transactions.isEmpty && !controller.loadingTransactions) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Chưa có giao dịch nào.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      );
    }
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!controller.canLoadMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Đã hiển thị tất cả giao dịch.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      );
    }
    return const SizedBox.shrink();
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
