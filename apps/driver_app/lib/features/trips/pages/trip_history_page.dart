import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/controllers/driver_home_controller.dart';
import '../../home/widgets/trip_card.dart';
import '../../trip_detail/pages/trip_detail_page.dart';
import '../models/trip_models.dart';

class TripHistoryPage extends StatelessWidget {
  const TripHistoryPage({super.key});

  static const routeName = '/history';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverHomeController>();
    final completedTrips = controller.assignments
        .where((trip) => trip.status == TripStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chuyến'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DriverHomeController>().refreshTrips(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Các chuyến đã hoàn thành gần đây',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (controller.loadingTrips && completedTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (completedTrips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 12),
                    Text(
                      'Bạn chưa có chuyến hoàn thành nào trong ca trực này.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                itemCount: completedTrips.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, index) {
                  final trip = completedTrips[index];
                  return TripCard(
                    trip: trip,
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        TripDetailPage.routeName,
                        arguments: TripDetailPageArgs(tripId: trip.id),
                      );
                      if (context.mounted) {
                        await context
                            .read<DriverHomeController>()
                            .refreshTrips();
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
