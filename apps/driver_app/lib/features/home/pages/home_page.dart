import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../driver/models/driver_models.dart';
import '../../trips/models/trip_models.dart';
import '../../trip_detail/pages/trip_detail_page.dart';
import '../../trips/pages/trip_history_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../wallet/pages/wallet_overview_page.dart';
import '../controllers/driver_home_controller.dart';
import '../widgets/driver_status_card.dart';
import '../widgets/trip_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverHomeController>().bootstrap();
    });
  }

  Future<void> _openTripDetail(String tripId) async {
    await Navigator.pushNamed(
      context,
      TripDetailPage.routeName,
      arguments: TripDetailPageArgs(tripId: tripId),
    );
    if (!mounted) return;
    await context.read<DriverHomeController>().refreshTrips();
  }

  Future<void> _refreshHome() async {
    final controller = context.read<DriverHomeController>();
    await Future.wait([
      controller.refreshProfile(),
      controller.refreshTrips(),
    ]);
  }

  Future<void> _refreshTripsOnly() {
    return context.read<DriverHomeController>().refreshTrips();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    context.read<DriverHomeController>().refreshTrips();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverHomeController>();
    final auth = context.watch<AuthController>();
    final body = controller.loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _selectedIndex,
            children: [
              _HomeTab(
                controller: controller,
                onRefresh: _refreshHome,
                onTripTap: _openTripDetail,
              ),
              _MyTripsTab(
                controller: controller,
                onRefresh: _refreshTripsOnly,
                onTripTap: _openTripDetail,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('UIT-Go Driver'),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ',
            onPressed: () {
              Navigator.pushNamed(context, DriverProfilePage.routeName);
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Ví của tôi',
            onPressed: () {
              Navigator.pushNamed(context, WalletOverviewPage.routeName);
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: auth.loggedIn
                ? () async {
                    await auth.logout();
                  }
                : null,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: body,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Chuyến của tôi',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.onRefresh,
    required this.onTripTap,
  });

  final DriverHomeController controller;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onTripTap;

  @override
  Widget build(BuildContext context) {
    final pendingTrips = controller.assignments
        .where((trip) => trip.status == TripStatus.requested)
        .toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DriverStatusCard(
            profile: controller.driver,
            isLoading: controller.togglingStatus,
            onToggle: (value) {
              final next = value
                  ? DriverAvailability.online
                  : DriverAvailability.offline;
              context.read<DriverHomeController>().toggleAvailability(next);
            },
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.red.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.error!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Chuyến được giao',
            subtitle: 'Các chuyến đang chờ bạn xác nhận',
          ),
          const SizedBox(height: 12),
          _TripsList(
            trips: pendingTrips,
            emptyLabel: 'Chưa có chuyến nào, chờ điều phối viên giao nhiệm vụ.',
            loading: controller.loadingTrips,
            onTap: onTripTap,
          ),
        ],
      ),
    );
  }
}

class _MyTripsTab extends StatelessWidget {
  const _MyTripsTab({
    required this.controller,
    required this.onRefresh,
    required this.onTripTap,
  });

  final DriverHomeController controller;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onTripTap;

  @override
  Widget build(BuildContext context) {
    final activeTrips = controller.assignments
        .where((trip) =>
            trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arriving ||
            trip.status == TripStatus.inRide)
        .toList();
    final completedTrips = controller.assignments
        .where((trip) => trip.status == TripStatus.completed)
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SectionHeader(
            title: 'Đang thực hiện',
            subtitle: 'Các chuyến bạn đã nhận',
          ),
          const SizedBox(height: 12),
          _TripsList(
            trips: activeTrips,
            emptyLabel: 'Bạn chưa nhận chuyến nào.',
            loading: controller.loadingTrips,
            onTap: onTripTap,
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Đã hoàn thành',
            subtitle: 'Hoàn tất trong ca trực này',
          ),
          const SizedBox(height: 12),
          _TripsList(
            trips: completedTrips,
            emptyLabel: 'Chưa có chuyến hoàn thành.',
            loading: controller.loadingTrips,
            onTap: onTripTap,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, TripHistoryPage.routeName);
              },
              icon: const Icon(Icons.history),
              label: const Text('Xem lịch sử chuyến'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList({
    required this.trips,
    required this.emptyLabel,
    required this.loading,
    required this.onTap,
  });

  final List<TripDetail> trips;
  final String emptyLabel;
  final bool loading;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && trips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (trips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.layers_clear, size: 32, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: trips.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          onTap: () => onTap(trip.id),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }
}
