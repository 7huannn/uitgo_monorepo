import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rider_app/features/trip/models/trip_models.dart';
import 'package:rider_app/features/trip/services/trip_service.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  final TripService _tripService = TripService();
  late Future<PagedTrips> _future;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _future = _loadTrips();
  }

  Future<PagedTrips> _loadTrips() {
    return _tripService.listTrips(role: 'rider');
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadTrips();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chuyến đi'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<PagedTrips>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }
            final data = snapshot.data;
            if (data == null || data.items.isEmpty) {
              return _buildEmptyState();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length,
              physics: const AlwaysScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = data.items[index];
                return _TripHistoryCard(
                  trip: trip,
                  timeLabel: _dateFormat.format(trip.createdAt),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Không thể tải lịch sử chuyến đi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.route, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Bạn chưa có chuyến đi nào.\nHãy đặt chuyến đầu tiên ngay hôm nay!',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({
    required this.trip,
    required this.timeLabel,
  });

  final TripDetail trip;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_taxi, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.serviceId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusChip(status: trip.status),
              ],
            ),
            const SizedBox(height: 12),
            _TripStopRow(
              icon: Icons.radio_button_checked,
              label: 'Điểm đón',
              value: trip.originText,
            ),
            const SizedBox(height: 8),
            _TripStopRow(
              icon: Icons.location_on_outlined,
              label: 'Điểm đến',
              value: trip.destText,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripStopRow extends StatelessWidget {
  const _TripStopRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _colorFromStatus() {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF1976D2);
    }
  }

  String _label() {
    switch (status) {
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFromStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
