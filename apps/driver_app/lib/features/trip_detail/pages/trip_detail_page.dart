import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

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
  final MapController _mapController = MapController();

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
      _fitMapToTrip(trip, location: trip.lastLocation);
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
        final latestTrip = _trip;
        if (event.location != null && latestTrip != null) {
          _fitMapToTrip(latestTrip, location: event.location);
        }
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
      _fitMapToTrip(refreshed);
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

  void _fitMapToTrip(TripDetail trip, {LocationUpdate? location}) {
    final points = <LatLng>[];
    final pickup = _latLng(trip.originLat, trip.originLng);
    final dropoff = _latLng(trip.destLat, trip.destLng);
    final driver = location ?? _latestLocation;
    if (pickup != null) points.add(pickup);
    if (dropoff != null) points.add(dropoff);
    if (driver != null) {
      points.add(LatLng(driver.latitude, driver.longitude));
    }
    if (points.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(36),
          ),
        );
      }
    });
  }

  LatLng? _latLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
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
                          _TripMap(
                            trip: trip,
                            location: _latestLocation,
                            statusColor: _statusColor(context, trip.status),
                            statusLabel: _statusLabel(trip.status),
                            mapController: _mapController,
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

class _TripMap extends StatelessWidget {
  const _TripMap({
    required this.trip,
    required this.location,
    required this.statusColor,
    required this.statusLabel,
    required this.mapController,
  });

  final TripDetail trip;
  final LocationUpdate? location;
  final Color statusColor;
  final String statusLabel;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final pickup = _toLatLng(trip.originLat, trip.originLng);
    final destination = _toLatLng(trip.destLat, trip.destLng);
    final driver = location == null
        ? null
        : LatLng(location!.latitude, location!.longitude);
    final fitPoints = [
      if (pickup != null) pickup,
      if (destination != null) destination,
      if (driver != null) driver,
    ];
    final initialCenter = fitPoints.isNotEmpty
        ? fitPoints.first
        : const LatLng(10.8702, 106.8033);
    final initialCameraFit = fitPoints.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(fitPoints),
            padding: const EdgeInsets.all(32),
          )
        : null;
    final distanceKm = trip.estimatedDistanceKm;
    final distanceLabel = distanceKm == null
        ? 'Đang tính toán quãng đường'
        : distanceKm >= 1
            ? '${distanceKm.toStringAsFixed(1)} km'
            : '${(distanceKm * 1000).toStringAsFixed(0)} m';
    final markers = <Marker>[
      if (pickup != null)
        Marker(
          point: pickup,
          width: 140,
          height: 80,
          alignment: Alignment.topCenter,
          child: _MapMarker(
            label: 'Điểm đón',
            value: trip.originText,
            color: Colors.green.shade600,
            icon: Icons.radio_button_checked,
          ),
        ),
      if (destination != null)
        Marker(
          point: destination,
          width: 140,
          height: 80,
          alignment: Alignment.topCenter,
          child: _MapMarker(
            label: 'Điểm trả',
            value: trip.destText,
            color: Colors.deepOrange.shade600,
            icon: Icons.flag,
            alignEnd: true,
          ),
        ),
      if (driver != null)
        Marker(
          point: driver,
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
            ),
          ),
        ),
    ];
    final polylines = <Polyline>[
      if (pickup != null && destination != null)
        Polyline(
          points: [pickup, destination],
          strokeWidth: 4,
          color: Theme.of(context).colorScheme.primary,
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 14,
                initialCameraFit: initialCameraFit,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
                keepAlive: true,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.uitgo.driver',
                ),
                if (polylines.isNotEmpty)
                  PolylineLayer(
                    polylines: polylines,
                  ),
                if (markers.isNotEmpty)
                  MarkerLayer(
                    markers: markers,
                  ),
              ],
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tài xế: ${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
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
                backgroundColor: Colors.black.withOpacity(0.4),
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

  LatLng? _toLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
