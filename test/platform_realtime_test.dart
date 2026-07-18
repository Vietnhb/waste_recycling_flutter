import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/core/platform_config.dart';
import 'package:waste_recycling_flutter/src/services/realtime_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  group('production endpoint configuration', () {
    test('compile-time endpoint overrides platform localhost defaults', () {
      expect(
        resolveApiBaseUrl(
          configured: ' https://api.green.test/api/// ',
          web: true,
          platform: TargetPlatform.android,
        ),
        'https://api.green.test/api',
      );
    });

    test('Android emulator keeps its local network bridge for development', () {
      expect(
        resolveApiBaseUrl(
          configured: '',
          web: false,
          platform: TargetPlatform.android,
        ),
        'http://10.0.2.2:8080/api',
      );
    });

    test('web release safely falls back to a same-origin API', () {
      expect(
        resolveApiBaseUrl(
          configured: '',
          web: true,
          platform: TargetPlatform.linux,
          release: true,
          webOrigin: 'https://green.example',
        ),
        'https://green.example/api',
      );
    });

    test('mobile release fails fast when its API endpoint is missing', () {
      expect(
        () => resolveApiBaseUrl(
          configured: '',
          web: false,
          platform: TargetPlatform.android,
          release: true,
        ),
        throwsStateError,
      );
    });

    test('realtime uses the public host without retaining the API path', () {
      expect(
        realtimeWebSocketUri('https://api.green.test/api', 'token-123'),
        Uri.parse('wss://api.green.test/ws/realtime?token=token-123'),
      );
    });
  });

  test(
    'logout cancels a reconnect already scheduled by a failed socket',
    () async {
      final channels = <_FakeWebSocketChannel>[];
      final service = RealtimeService(
        reconnectDelay: const Duration(milliseconds: 20),
        connector: (_) {
          final channel = _FakeWebSocketChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(service.dispose);

      service.connect(
        baseUrl: 'https://api.green.test/api',
        token: 'expired-after-logout',
      );
      expect(channels, hasLength(1));

      channels.single.fail();
      await Future<void>.delayed(Duration.zero);
      service.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(channels, hasLength(1));
    },
  );

  test(
    'a newer server connection invalidates the old reconnect timer',
    () async {
      final openedUris = <Uri>[];
      final channels = <_FakeWebSocketChannel>[];
      final service = RealtimeService(
        reconnectDelay: const Duration(milliseconds: 20),
        connector: (uri) {
          openedUris.add(uri);
          final channel = _FakeWebSocketChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(service.dispose);

      service.connect(baseUrl: 'https://old.test/api', token: 'old-token');
      channels.single.fail();
      await Future<void>.delayed(Duration.zero);
      service.connect(baseUrl: 'https://new.test/api', token: 'new-token');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(openedUris, hasLength(2));
      expect(openedUris.last.host, 'new.test');
    },
  );
}

class _FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final _controller = StreamController<dynamic>();
  final _sink = _FakeWebSocketSink();

  void fail() => _controller.addError(StateError('socket failed'));

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _controller.stream;
}

class _FakeWebSocketSink implements WebSocketSink {
  final _done = Completer<void>();

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.drain<void>();

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}
