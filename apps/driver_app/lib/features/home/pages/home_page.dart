import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../driver/models/driver_models.dart';
import '../../trips/models/trip_models.dart';
import '../../trip_detail/pages/trip_detail_page.dart';
import '../controllers/driver_home_controller.dart';
import '../widgets/driver_status_card.dart';
import '../widgets/trip_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  static const route = '/';

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
        title: const Text('UIT-Go Driver'),
        actions: [
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
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<DriverHomeController>().refreshTrips(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  DriverStatusCard(
                    profile: controller.driver,
                    isLoading: controller.togglingStatus,
                    onToggle: (value) {
                      final next = value ? DriverAvailability.online : DriverAvailability.offline;
                      context.read<DriverHomeController>().toggleAvailability(next);
                    },
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      controller.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Chuyến được giao',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (controller.loadingTrips)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ))
                  else if (controller.assignments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Chưa có chuyến nào, chờ điều phối viên giao nhiệm vụ.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...controller.assignments.map(
                      (trip) => TripCard(
                        trip: trip,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(tripId: trip.id),
                            ),
                          );
                          if (mounted) {
                            await context.read<DriverHomeController>().refreshTrips();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<DriverHomeController>().refreshTrips(),
        icon: const Icon(Icons.refresh),
        label: const Text('Làm mới'),
      ),
    );
  }
}
