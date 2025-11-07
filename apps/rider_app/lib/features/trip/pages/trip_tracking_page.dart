import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_models.dart';
import '../services/trip_service.dart';

class TripTrackingPage extends StatefulWidget {
  const TripTrackingPage({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  final String tripId;
  final TripDetail? initialTrip;

  @override
  State<TripTrackingPage> createState() => _TripTrackingPageState();
}

class _TripTrackingPageState extends State<TripTrackingPage> {
  final TripService _tripService = TripService();
  final MapController _mapController = MapController();

  StreamSubscription<TripRealtimeEvent>? _subscription;
  TripDetail? _trip;
  LocationUpdate? _latestLocation;
  String? _status;
  bool _loadingTrip = true;
  bool _connecting = true;
  bool _mapReady = false;
  String? _tripError;
  String? _socketError;
  LatLng? _pendingCenter;

  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;

  static const LatLng _defaultCenter = LatLng(10.8705, 106.8032);
  static const double _defaultZoom = 15;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    _status = _trip?.status;
    _latestLocation = _trip?.lastLocation;
    _pickupLatLng = _guessLatLng(_trip?.originText);
    _destinationLatLng = _guessLatLng(_trip?.destText);
    _loadingTrip = _trip == null;

    unawaited(_loadTripIfNeeded());
    unawaited(_connectToTrip());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_tripService.closeChannel());
    super.dispose();
  }

  Future<void> _loadTripIfNeeded() async {
    if (_trip != null) {
      setState(() {
        _loadingTrip = false;
      });
      _moveCameraToCurrentLocation();
      return;
    }

    try {
      final detail = await _tripService.fetchTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = detail;
        _status = detail.status;
        _loadingTrip = false;
        _pickupLatLng ??= _guessLatLng(detail.originText);
        _destinationLatLng ??= _guessLatLng(detail.destText);
        _latestLocation = detail.lastLocation ?? _latestLocation;
      });
      _moveCameraToCurrentLocation();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tripError = 'Không tải được thông tin chuyến: $error';
        _loadingTrip = false;
      });
    }
  }

  Future<void> _connectToTrip() async {
    setState(() {
      _connecting = true;
      _socketError = null;
    });

    try {
      final stream = await _tripService.connectToTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _connecting = false;
      });
      _subscription = stream.listen(
        _handleRealtimeEvent,
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _socketError = 'Mất kết nối realtime: $error';
            _connecting = false;
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _socketError = 'Không thể kết nối realtime: $error';
        _connecting = false;
      });
    }
  }

  void _handleRealtimeEvent(TripRealtimeEvent event) {
    if (!mounted) return;
    if (event.type == RealtimeEventType.location && event.location != null) {
      setState(() {
        _latestLocation = event.location;
      });
      _moveCameraToCurrentLocation();
    } else if (event.type == RealtimeEventType.status && event.status != null) {
      setState(() {
        _status = event.status;
      });
    }
  }

  LatLng? get _driverLatLng {
    final location = _latestLocation;
    if (location == null) return null;
    return LatLng(location.latitude, location.longitude);
  }

  LatLng get _initialCenter {
    return _driverLatLng ??
        _pickupLatLng ??
        _destinationLatLng ??
        _defaultCenter;
  }

  void _moveCameraToCurrentLocation() {
    final target = _driverLatLng ?? _pickupLatLng ?? _destinationLatLng;
    if (target == null) return;
    _centerMap(target);
  }

  void _centerMap(LatLng target, {double? zoom}) {
    if (_mapReady) {
      final currentZoom = zoom ?? _mapController.camera.zoom;
      _mapController.move(target, currentZoom);
    } else {
      _pendingCenter = target;
    }
  }

  LatLng? _guessLatLng(String? description) {
    if (description == null || description.isEmpty) return null;
    final key = description.toLowerCase();
    if (key.contains('uit')) {
      return const LatLng(10.8705, 106.8032);
    }
    if (key.contains('khu b') || key.contains('ktx')) {
      return const LatLng(10.8815, 106.8058);
    }
    if (key.contains('thủ đức')) {
      return const LatLng(10.8709, 106.7773);
    }
    if (key.contains('quận 1')) {
      return const LatLng(10.7757, 106.7004);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi chuyến đi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Đưa tới vị trí tài xế',
            onPressed: _driverLatLng != null ? () => _centerMap(_driverLatLng!) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMap()),
          _buildTripDetails(trip),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final markers = _buildMarkers();
    final polylines = _buildPolylines();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _defaultZoom,
            onMapReady: () {
              setState(() {
                _mapReady = true;
              });
              if (_pendingCenter != null) {
                _mapController.move(_pendingCenter!, _defaultZoom);
                _pendingCenter = null;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.uitgo.rider',
              tileProvider: CancellableNetworkTileProvider(),
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
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(),
                  if (_connecting)
                    const Chip(
                      avatar: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text('Đang kết nối'),
                    ),
                ],
              ),
              if (_socketError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildWarningBanner(_socketError!),
                ),
            ],
          ),
        ),
        if (_loadingTrip)
          const Align(
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          point: _pickupLatLng!,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: _MapMarker(
            label: 'Điểm đón',
            color: Colors.green.shade600,
            icon: Icons.radio_button_checked,
          ),
        ),
      );
    }
    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          point: _destinationLatLng!,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: _MapMarker(
            label: 'Điểm đến',
            color: Colors.red.shade600,
            icon: Icons.location_on,
          ),
        ),
      );
    }
    if (_driverLatLng != null) {
      markers.add(
        Marker(
          point: _driverLatLng!,
          width: 60,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: const _DriverMarker(
            bearing: 0,
          ),
        ),
      );
    }
    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      return const <Polyline>[];
    }
    return [
      Polyline(
        points: [_pickupLatLng!, _destinationLatLng!],
        color: Colors.indigo.shade400.withValues(alpha: 0.7),
        strokeWidth: 4,
      ),
    ];
  }

  Widget _buildTripDetails(TripDetail? trip) {
    final statusText = _status != null ? _statusLabel(_status!) : 'Đang cập nhật';
    final originText = trip?.originText ?? 'Đang tải...';
    final destText = trip?.destText ?? 'Đang tải...';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(30, 0, 0, 0),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${widget.tripId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: _driverLatLng != null
                          ? () => _centerMap(_driverLatLng!, zoom: 17)
                          : null,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Theo dõi'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.radio_button_checked,
            color: Colors.green.shade600,
            title: 'Điểm đón',
            value: originText,
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.location_on,
            color: Colors.red.shade600,
            title: 'Điểm đến',
            value: destText,
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.my_location,
            color: Colors.blue.shade600,
            title: 'Tài xế',
            value: _latestLocation != null
                ? '${_latestLocation!.latitude.toStringAsFixed(5)}, ${_latestLocation!.longitude.toStringAsFixed(5)}'
                : 'Đang đợi cập nhật...',
          ),
          if (_tripError != null || _socketError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildWarningBanner(_tripError ?? _socketError!),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    final status = _status;
    if (status == null) {
      return const Chip(
        avatar: Icon(Icons.hourglass_empty, size: 16),
        label: Text('Đang chờ cập nhật'),
      );
    }
    final label = _statusLabel(status);
    final color = _statusColor(status);
    return Chip(
      avatar: Icon(Icons.directions_bike, size: 16, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return const Color(0xFF667EEA);
      case 'accepted':
        return const Color(0xFF11998E);
      case 'arriving':
        return const Color(0xFFFFA751);
      case 'in_ride':
        return const Color(0xFF764BA2);
      case 'completed':
        return const Color(0xFF38EF7D);
      case 'cancelled':
        return const Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return 'Đang tìm tài xế';
      case 'accepted':
        return 'Đã nhận chuyến';
      case 'arriving':
        return 'Tài xế đang tới';
      case 'in_ride':
        return 'Đang di chuyển';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Icon(icon, color: color, size: 28),
      ],
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.directions_bike,
        color: Colors.white,
      ),
    );
  }
}
