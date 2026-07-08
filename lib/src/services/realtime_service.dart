import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/json_helpers.dart';

class RealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  final _events = StreamController<JsonMap>.broadcast();

  Stream<JsonMap> get events => _events.stream;

  void connect({required String baseUrl, required String token}) {
    disconnect();
    final uri = _wsUri(baseUrl, token);
    _channel = WebSocketChannel.connect(uri);
    _socketSub = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString());
          if (data is Map<String, dynamic>) _events.add(data);
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(baseUrl, token),
      onDone: () => _scheduleReconnect(baseUrl, token),
      cancelOnError: true,
    );
  }

  void disconnect() {
    _socketSub?.cancel();
    _socketSub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }

  void _scheduleReconnect(String baseUrl, String token) {
    disconnect();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (token.isNotEmpty) connect(baseUrl: baseUrl, token: token);
    });
  }

  Uri _wsUri(String baseUrl, String token) {
    final api = Uri.parse(baseUrl);
    final scheme = api.scheme == 'https' ? 'wss' : 'ws';
    return api.replace(
      scheme: scheme,
      path: '/ws/realtime',
      queryParameters: {'token': token},
    );
  }
}
