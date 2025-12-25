import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../driver/models/driver_models.dart';
import '../../profile/pages/profile_page.dart';
import '../../wallet/pages/wallet_overview_page.dart';
import '../controllers/driver_home_controller.dart';
import '../../trips/models/trip_models.dart';
import '../../trip_detail/pages/trip_detail_page.dart';
import '../../trips/pages/trip_history_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverHomeController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverHomeController>();
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển tài xế'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Hồ sơ',
            onPressed: () =>
                Navigator.pushNamed(context, DriverProfilePage.routeName),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async => await auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.refreshProfile();
          await controller.refreshTrips();
          await controller.refreshWallet();
        },
        child: controller.loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DriverStatusHeader(),
                    SizedBox(height: 24),
                    _EarningsSummary(),
                    SizedBox(height: 24),
                    _QuickActions(),
                    SizedBox(height: 24),
                    _CurrentTripSection(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DriverStatusHeader extends StatelessWidget {
  const _DriverStatusHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DriverHomeController>();
    final driver = controller.driver;
    final isOnline = driver?.availability == DriverAvailability.online;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Icon(Icons.person_outline, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver?.fullName ?? 'Loading...',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isOnline ? Colors.green.shade600 : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.2,
              child: Switch(
                value: isOnline,
                onChanged: controller.togglingStatus
                    ? null
                    : (value) {
                        final availability =
                            value ? DriverAvailability.online : DriverAvailability.offline;
                        controller.toggleAvailability(availability);
                      },
                thumbIcon: MaterialStateProperty.resolveWith<Icon?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Icon(Icons.check);
                    }
                    return const Icon(Icons.close);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  const _EarningsSummary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DriverHomeController>();
    final summary = controller.walletSummary;
    final today = summary?.recentEarnings.isNotEmpty == true
        ? summary!.recentEarnings.first.amount
        : null;
    final week = summary?.weeklyRevenue;
    return Card(
       elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thu nhập', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEarningItem(
                  context,
                  'Hôm nay',
                  amount: today,
                  loading: controller.loading,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.dividerColor,
                ),
                _buildEarningItem(
                  context,
                  'Tuần này',
                  amount: week,
                  loading: controller.loading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem(BuildContext context,
      String label, {
        double? amount,
        bool loading = false,
      }) {
    final theme = Theme.of(context);
    final formattedAmount = amount == null
        ? 'Đang cập nhật'
        : NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);

    return Column(
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          formattedAmount,
          style: (amount == null
                  ? theme.textTheme.bodyLarge
                  : theme.textTheme.headlineSmall)
              ?.copyWith(
            fontWeight: amount == null ? FontWeight.w600 : FontWeight.bold,
            color: amount == null ? Colors.grey[700] : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem(
          context,
          icon: Icons.account_balance_wallet_outlined,
          label: 'Ví',
          onTap: () =>
              Navigator.pushNamed(context, WalletOverviewPage.routeName),
        ),
        _buildActionItem(
          context,
          icon: Icons.history_outlined,
          label: 'Lịch sử',
          onTap: () => Navigator.pushNamed(
            context,
            TripHistoryPage.routeName,
          ),
        ),
        _buildActionItem(
          context,
          icon: Icons.notifications_outlined,
          label: 'Thông báo',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng thông báo sẽ sớm khả dụng.')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 12),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class _CurrentTripSection extends StatelessWidget {
  const _CurrentTripSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DriverHomeController>();
    TripDetail? currentTrip;
    for (final trip in controller.assignments) {
      if (trip.status != TripStatus.completed &&
          trip.status != TripStatus.cancelled) {
        currentTrip = trip;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoạt động hiện tại',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
           elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: currentTrip != null
              ? ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.navigation_outlined, size: 40),
                  title: Text(currentTrip.destText, style: theme.textTheme.titleMedium),
                  subtitle: Text('Trip ID: ${currentTrip.id}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      TripDetailPage.routeName,
                      arguments: TripDetailPageArgs(tripId: currentTrip!.id),
                    );
                    if (result == true && context.mounted) {
                      await controller.refreshTrips();
                    }
                  },
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 16),
                  child: Center(
                    child: Text(
                      'Chưa có chuyến nào. Bật trạng thái sẵn sàng để nhận chuyến.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
