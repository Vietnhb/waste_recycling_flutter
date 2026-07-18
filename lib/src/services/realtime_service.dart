import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/json_helpers.dart';

typedef RealtimeChannelConnector = WebSocketChannel Function(Uri uri);

const realtimeSyncRequiredEvent = 'SYNC_REQUIRED';

class RealtimeService {
  RealtimeService({
    RealtimeChannelConnector? connector,
    Duration reconnectDelay = const Duration(seconds: 3),
  }) : _connector = connector ?? WebSocketChannel.connect,
       _reconnectDelay = reconnectDelay;

  final RealtimeChannelConnector _connector;
  final Duration _reconnectDelay;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  final _events = StreamController<JsonMap>.broadcast();
  Timer? _reconnectTimer;
  String? _baseUrl;
  String? _token;
  int _connectionGeneration = 0;
  int _successfulConnections = 0;
  bool _reconnectEnabled = false;
  bool _disposed = false;

  Stream<JsonMap> get events => _events.stream;

  @visibleForTesting
  void addTestEvent(JsonMap event) {
    if (!_events.isClosed) _events.add(event);
  }

  void connect({required String baseUrl, required String token}) {
    if (_disposed) return;
    if (token.isEmpty) {
      disconnect();
      return;
    }
    _baseUrl = baseUrl;
    _token = token;
    _reconnectEnabled = true;
    _reconnectTimer?.cancel();
    _openConnection();
  }

  void _openConnection() {
    final baseUrl = _baseUrl;
    final token = _token;
    if (!_reconnectEnabled || baseUrl == null || token == null) return;

    _closeConnection();
    final generation = _connectionGeneration;
    final uri = realtimeWebSocketUri(baseUrl, token);
    late final WebSocketChannel channel;
    try {
      channel = _connector(uri);
    } catch (_) {
      _scheduleReconnect(generation);
      return;
    }
    _channel = channel;
    unawaited(
      channel.ready.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          _scheduleReconnect(generation);
        },
      ),
    );
    _socketSub = channel.stream.listen(
      (message) {
        if (generation != _connectionGeneration || _events.isClosed) return;
        try {
          final data = jsonDecode(message.toString());
          if (data is! Map<String, dynamic>) return;
          if (asString(data['type']).trim().toUpperCase() == 'CONNECTED') {
            _successfulConnections++;
            if (_successfulConnections > 1) {
              _events.add({
                ...data,
                'type': realtimeSyncRequiredEvent,
                'reason': 'RECONNECTED',
              });
            }
            return;
          }
          _events.add(data);
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(generation),
      onDone: () => _scheduleReconnect(generation),
      cancelOnError: true,
    );
  }

  void disconnect() {
    _reconnectEnabled = false;
    _baseUrl = null;
    _token = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _successfulConnections = 0;
    _closeConnection();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    _events.close();
  }

  void _closeConnection() {
    _connectionGeneration++;
    final subscription = _socketSub;
    final channel = _channel;
    _socketSub = null;
    _channel = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (channel != null) unawaited(channel.sink.close());
  }

  void _scheduleReconnect(int generation) {
    if (_disposed ||
        !_reconnectEnabled ||
        generation != _connectionGeneration) {
      return;
    }
    _closeConnection();
    final reconnectGeneration = _connectionGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_disposed ||
          !_reconnectEnabled ||
          reconnectGeneration != _connectionGeneration) {
        return;
      }
      _openConnection();
    });
  }
}

Uri realtimeWebSocketUri(String baseUrl, String token) {
  final api = Uri.parse(baseUrl);
  final scheme = api.scheme == 'https' ? 'wss' : 'ws';
  return api.replace(
    scheme: scheme,
    path: '/ws/realtime',
    queryParameters: {'token': token},
  );
}
