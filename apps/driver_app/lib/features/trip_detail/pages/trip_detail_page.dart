import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/primary_button.dart';
import '../../trips/models/trip_models.dart';
import '../../trips/services/trip_service.dart';
import '../../trips/services/trip_socket_service.dart';

class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết chuyến'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _trip == null
                  ? const Center(child: Text('Chuyến không tồn tại'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          _TripSummary(trip: _trip!, location: _latestLocation),
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
          PrimaryButton(
            label: 'Chấp nhận chuyến',
            onPressed: _actionLoading ? null : _accept,
            loading: _actionLoading,
          ),
        );
        widgets.add(
          TextButton(
            onPressed: _actionLoading ? null : _decline,
            child: const Text('Từ chối'),
          ),
        );
        break;
      case 'accepted':
        widgets.add(
          PrimaryButton(
            label: 'Đang tới điểm đón',
            onPressed: _actionLoading ? null : () => _updateStatus(TripStatus.arriving),
            loading: _actionLoading,
          ),
        );
        break;
      case 'arriving':
        widgets.add(
          PrimaryButton(
            label: 'Đã đón khách',
            onPressed: _actionLoading ? null : () => _updateStatus(TripStatus.inRide),
            loading: _actionLoading,
          ),
        );
        break;
      case 'in_ride':
        widgets.add(
          PrimaryButton(
            label: 'Hoàn thành chuyến',
            onPressed: _actionLoading ? null : () => _updateStatus(TripStatus.completed),
            loading: _actionLoading,
          ),
        );
        break;
      default:
        widgets.add(
          Chip(
            label: Text(
              trip.status.value == 'completed' ? 'Đã hoàn thành' : 'Đã kết thúc',
            ),
          ),
        );
        break;
    }

    return widgets;
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip, this.location});

  final TripDetail trip;
  final LocationUpdate? location;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm dd/MM');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.serviceId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_pin, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.originText)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.destText)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Trạng thái hiện tại: ${trip.status.value}'),
            const SizedBox(height: 4),
            Text('Cập nhật: ${formatter.format(trip.updatedAt)}'),
            if (location != null) ...[
              const SizedBox(height: 12),
              Text(
                'Vị trí mới nhất: '
                '${location!.latitude.toStringAsFixed(5)}, '
                '${location!.longitude.toStringAsFixed(5)}',
              ),
              Text('Thời gian: ${formatter.format(location!.timestamp)}'),
            ],
          ],
        ),
      ),
    );
  }
}
