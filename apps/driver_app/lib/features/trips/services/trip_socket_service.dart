import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/config.dart';
import '../../auth/services/auth_service.dart';
import '../models/trip_models.dart';

class TripSocketService {
  TripSocketService._internal();
  static final TripSocketService _instance = TripSocketService._internal();
  factory TripSocketService() => _instance;

  final AuthService _auth = AuthService();
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _controller = StreamController<TripRealtimeEvent>.broadcast();
  Timer? _locationTimer;
  final _locationEmitter = _DriverLocationEmitter();

  Stream<TripRealtimeEvent> get stream => _controller.stream;

  Future<void> connect(String tripId) async {
    await disconnect();

    if (useMock) {
      _locationTimer?.cancel();
      _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        final update = _locationEmitter.next();
        _controller.add(TripRealtimeEvent.location(update));
      });
      return;
    }

    final userInfo = await _auth.getUserInfo();
    final userId = userInfo['userId']?.isNotEmpty == true ? userInfo['userId']! : 'demo-driver';

    final uri = _buildUri(tripId, userId);
    _channel = WebSocketChannel.connect(uri);
    _channelSub = _channel!.stream.listen(_handleInbound);
    _startLocationTicker();
  }

  void _handleInbound(dynamic data) {
    try {
      final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
      _controller.add(TripRealtimeEvent.fromJson(jsonMap));
    } catch (_) {
      // ignore malformed payloads
    }
  }

  void sendStatus(TripStatus status) {
    _channel?.sink.add(jsonEncode({
      'type': 'status',
      'status': status.value,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  void _startLocationTicker() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final update = _locationEmitter.next();
      _channel?.sink.add(jsonEncode({
        'type': 'location',
        'lat': update.latitude,
        'lng': update.longitude,
        'timestamp': update.timestamp.toIso8601String(),
      }));
      _controller.add(TripRealtimeEvent.location(update));
    });
  }

  Future<void> disconnect() async {
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Uri _buildUri(String tripId, String userId) {
    final baseUri = Uri.parse(apiBase);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = baseUri.path.endsWith('/')
        ? '${baseUri.path}v1/trips/$tripId/ws'
        : '${baseUri.path}/v1/trips/$tripId/ws';
    return baseUri.replace(
      scheme: scheme,
      path: basePath,
      queryParameters: {
        'role': 'driver',
        'userId': userId,
      },
    );
  }
}

class _DriverLocationEmitter {
  _DriverLocationEmitter()
      : _lat = 10.8705,
        _lng = 106.8032,
        _rand = Random();

  double _lat;
  double _lng;
  final Random _rand;

  LocationUpdate next() {
    _lat += (_rand.nextDouble() - 0.5) * 0.0005;
    _lng += (_rand.nextDouble() - 0.5) * 0.0005;
    return LocationUpdate(
      latitude: _lat,
      longitude: _lng,
      timestamp: DateTime.now(),
    );
  }
}
