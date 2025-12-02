import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
}) {
  // Browsers ignore custom headers; the token must be passed via query params.
  return HtmlWebSocketChannel.connect(uri.toString());
}
