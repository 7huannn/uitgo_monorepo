import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TripWsClient {
  TripWsClient({
    required this.baseUrl,
    required this.tripId,
    required this.role,
    required this.accessToken,
    this.userIdOverride,
  });

  final String baseUrl;
  final String tripId;
  final String role;
  final String accessToken;
  final String? userIdOverride;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Stream<dynamic>? get stream => _channel?.stream;

  Future<void> connect({
    void Function(dynamic data)? onMessage,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) async {
    await disconnect();
    final uri = _buildWsUri();
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) {
        onMessage?.call(data);
      },
      onError: (err) {
        onError?.call(err);
      },
      onDone: onDone,
      cancelOnError: true,
    );
  }

  Uri _buildWsUri() {
    final base = Uri.parse(baseUrl.trim());
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    var basePath = base.path;
    if (basePath.isEmpty) {
      basePath = '/';
    } else if (!basePath.endsWith('/')) {
      basePath = '$basePath/';
    }
    final path = '$basePath' 'v1/trips/$tripId/ws';
    final params = <String, String>{
      'role': role,
      if (accessToken.isNotEmpty) 'accessToken': accessToken,
      if (userIdOverride != null && userIdOverride!.trim().isNotEmpty)
        'userId': userIdOverride!.trim(),
    };
    return base.replace(scheme: scheme, path: path, queryParameters: params);
  }

  void sendStatus(String status) {
    _channel?.sink.add(jsonEncode({'type': 'status', 'status': status}));
  }

  void sendLocation(double lat, double lng) {
    _channel?.sink.add(jsonEncode({
      'type': 'location',
      'lat': lat,
      'lng': lng,
    }));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  bool get isConnected => _channel != null;
}
