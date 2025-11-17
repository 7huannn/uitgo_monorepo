import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../trips/models/trip_models.dart';
import '../../trips/services/trip_service.dart';
import '../../trips/services/trip_socket_service.dart';

class TripDetailPageArgs {
  const TripDetailPageArgs({required this.tripId});

  final String tripId;
}

class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  static const routeName = '/trip_detail';

  final String tripId;

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final TripService _tripService = TripService();
  final TripSocketService _socket = TripSocketService();

  TripDetail? _trip;
  LocationUpdate? _latestLocation;
  bool _loading = true;
  bool _actionLoading = false;
  StreamSubscription? _socketSub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trip = await _tripService.fetchTrip(widget.tripId);
      setState(() {
        _trip = trip;
        _latestLocation = trip.lastLocation;
      });
      await _socket.connect(widget.tripId);
      _socketSub = _socket.stream.listen((event) {
        if (!mounted) return;
        setState(() {
          if (event.status != null) {
            _trip = _trip?.copyWith(status: event.status);
          }
          if (event.location != null) {
            _latestLocation = event.location;
          }
        });
      });
    } catch (e) {
      setState(() => _error = 'Không thể tải thông tin chuyến.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept() async {
    await _runAction(() async {
      await _tripService.acceptTrip(widget.tripId);
      _socket.sendStatus(TripStatus.accepted);
    });
  }

  Future<void> _decline() async {
    await _runAction(() async {
      await _tripService.declineTrip(widget.tripId);
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateStatus(TripStatus status) async {
    await _runAction(() async {
      await _tripService.updateTripStatus(widget.tripId, status);
      _socket.sendStatus(status);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await action();
      final refreshed = await _tripService.fetchTrip(widget.tripId);
      setState(() => _trip = refreshed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thao tác thất bại, thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Color _statusColor(BuildContext context, TripStatus status) {
    switch (status.value) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'arriving':
        return Colors.teal;
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

  String _statusLabel(TripStatus status) {
    switch (status.value) {
      case 'requested':
        return 'Chờ chấp nhận';
      case 'accepted':
        return 'Đang tới điểm đón';
      case 'arriving':
        return 'Chuẩn bị đón khách';
      case 'in_ride':
        return 'Đang chở khách';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết chuyến'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _loadTrip,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : trip == null
                  ? const Center(child: Text('Chuyến không tồn tại'))
                  : RefreshIndicator(
                      onRefresh: _loadTrip,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _MapPlaceholder(
                            trip: trip,
                            location: _latestLocation,
                            statusColor: _statusColor(context, trip.status),
                            statusLabel: _statusLabel(trip.status),
                          ),
                          const SizedBox(height: 16),
                          _TripDetailsCard(
                            trip: trip,
                            location: _latestLocation,
                            statusColor: _statusColor(context, trip.status),
                            statusLabel: _statusLabel(trip.status),
                          ),
                          const SizedBox(height: 16),
                          _TripMetaCard(trip: trip),
                          const SizedBox(height: 24),
                          ..._buildActions(),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _buildActions() {
    final trip = _trip;
    if (trip == null) return [];
    final widgets = <Widget>[];

    switch (trip.status.value) {
      case 'requested':
        widgets.add(
          UitPrimaryButton(
            label: 'Chấp nhận chuyến',
            onPressed: _actionLoading ? null : _accept,
            loading: _actionLoading,
            icon: const Icon(Icons.check),
          ),
        );
        widgets.add(
          TextButton(
            onPressed: _actionLoading ? null : _decline,
            child: const Text('Từ chối chuyến'),
          ),
        );
        break;
      case 'accepted':
        widgets.add(
          UitPrimaryButton(
            label: 'Bắt đầu di chuyển',
            onPressed: _actionLoading
                ? null
                : () => _updateStatus(TripStatus.arriving),
            loading: _actionLoading,
            icon: const Icon(Icons.directions_car),
          ),
        );
        break;
      case 'arriving':
        widgets.add(
          UitPrimaryButton(
            label: 'Đã đón khách',
            onPressed:
                _actionLoading ? null : () => _updateStatus(TripStatus.inRide),
            loading: _actionLoading,
            icon: const Icon(Icons.person_pin_circle),
          ),
        );
        break;
      case 'in_ride':
        widgets.add(
          UitPrimaryButton(
            label: 'Hoàn thành chuyến',
            onPressed: _actionLoading
                ? null
                : () => _updateStatus(TripStatus.completed),
            loading: _actionLoading,
            icon: const Icon(Icons.flag),
          ),
        );
        break;
      default:
        widgets.add(
          Chip(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            label: Text(
              trip.status.value == 'completed'
                  ? 'Chuyến đã hoàn tất'
                  : 'Chuyến đã kết thúc',
            ),
          ),
        );
        break;
    }

    return widgets;
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.trip,
    required this.location,
    required this.statusColor,
    required this.statusLabel,
  });

  final TripDetail trip;
  final LocationUpdate? location;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final distanceKm = trip.estimatedDistanceKm;
    final distanceLabel = distanceKm == null
        ? 'Đang tính toán quãng đường'
        : distanceKm >= 1
            ? '${distanceKm.toStringAsFixed(1)} km'
            : '${(distanceKm * 1000).toStringAsFixed(0)} m';
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 220,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D3557), Color(0xFF457B9D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            Positioned(
              top: 24,
              left: 24,
              child: _MapPoint(
                label: 'Điểm đón',
                value: trip.originText,
                color: Colors.greenAccent,
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: _MapPoint(
                label: 'Điểm trả',
                value: trip.destText,
                color: Colors.orangeAccent,
                alignEnd: true,
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Vị trí: ${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Chip(
                backgroundColor: Colors.white.withOpacity(0.2),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      trip.serviceId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({
    required this.trip,
    required this.location,
    required this.statusColor,
    required this.statusLabel,
  });

  final TripDetail trip;
  final LocationUpdate? location;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm dd/MM');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Trạng thái chuyến',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Chip(
                  backgroundColor: statusColor.withOpacity(0.15),
                  label: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TimelinePoint(
              title: 'Điểm đón',
              subtitle: trip.originText,
              icon: Icons.radio_button_checked,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _TimelinePoint(
              title: 'Điểm trả',
              subtitle: trip.destText,
              icon: Icons.flag,
              color: Colors.blue,
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tạo lúc ${formatter.format(trip.createdAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.update, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cập nhật ${formatter.format(trip.updatedAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vị trí mới nhất cập nhật ${formatter.format(location!.timestamp)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripMetaCard extends StatelessWidget {
  const _TripMetaCard({required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    final distanceKm = trip.estimatedDistanceKm;
    final distanceLabel = distanceKm == null
        ? '--'
        : distanceKm >= 1
            ? '${distanceKm.toStringAsFixed(1)} km'
            : '${(distanceKm * 1000).toStringAsFixed(0)} m';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin dịch vụ',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_taxi),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.serviceId,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.straighten),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quãng đường dự kiến: $distanceLabel',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mã hành khách: ${trip.riderId}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPoint extends StatelessWidget {
  const _MapPoint({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(24, size.height - 24)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.6,
        size.width * 0.75,
        size.height * 0.4,
        size.width - 24,
        24,
      );
    canvas.drawPath(path, paint);
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), dashPaint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
