import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
}) {
  throw UnsupportedError(
    'WebSockets are not available on this platform: $uri',
  );
}
