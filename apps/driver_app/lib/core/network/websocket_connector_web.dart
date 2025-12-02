import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, dynamic>? headers,
}) {
  // Custom headers are not supported by browsers, so tokens must be in the URL.
  return HtmlWebSocketChannel.connect(uri.toString());
}
