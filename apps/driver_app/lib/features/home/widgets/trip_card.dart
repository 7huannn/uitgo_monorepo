import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../trips/models/trip_models.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
  });

  final TripDetail trip;
  final VoidCallback? onTap;

  Color _statusColor(BuildContext context) {
    switch (trip.status.value) {
      case 'accepted':
        return Colors.blue;
      case 'arriving':
        return Colors.orange;
      case 'in_ride':
        return Colors.deepPurple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel() {
    switch (trip.status.value) {
      case 'requested':
        return 'Chờ xác nhận';
      case 'accepted':
        return 'Đã nhận chuyến';
      case 'arriving':
        return 'Đang đến điểm đón';
      case 'in_ride':
        return 'Đang thực hiện';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return trip.status.value;
    }
  }

  String _distanceLabel() {
    final distanceKm = trip.estimatedDistanceKm;
    if (distanceKm == null) {
      return 'Đang tính';
    }
    if (distanceKm >= 1) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    final meters = (distanceKm * 1000).round();
    return '$meters m';
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm dd/MM');
    final statusColor = _statusColor(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_taxi, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.serviceId,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tạo lúc ${formatter.format(trip.createdAt)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    backgroundColor: statusColor.withOpacity(0.15),
                    label: Text(
                      _statusLabel(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LocationRow(
                icon: Icons.radio_button_checked,
                label: 'Điểm đón',
                value: trip.originText,
                iconColor: Colors.green,
              ),
              const SizedBox(height: 12),
              _LocationRow(
                icon: Icons.flag,
                label: 'Điểm trả',
                value: trip.destText,
                iconColor: Colors.blue,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.route,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quãng đường: ${_distanceLabel()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(Icons.schedule, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Cập nhật ${formatter.format(trip.updatedAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
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
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
