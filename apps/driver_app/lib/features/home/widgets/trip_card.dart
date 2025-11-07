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

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm dd/MM');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text('${trip.originText} → ${trip.destText}'),
        subtitle: Text('Cập nhật lúc ${formatter.format(trip.updatedAt)}'),
        trailing: Chip(
          backgroundColor: _statusColor(context).withOpacity(0.1),
          label: Text(
            trip.status.value,
            style: TextStyle(color: _statusColor(context)),
          ),
        ),
      ),
    );
  }
}
