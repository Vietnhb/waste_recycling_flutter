import 'package:flutter/foundation.dart';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String defaultApiBaseUrl() {
  return resolveApiBaseUrl(
    configured: _configuredApiBaseUrl,
    web: kIsWeb,
    platform: defaultTargetPlatform,
    release: kReleaseMode,
    webOrigin: kIsWeb ? Uri.base.origin : '',
  );
}

String resolveApiBaseUrl({
  required String configured,
  required bool web,
  required TargetPlatform platform,
  bool release = false,
  String webOrigin = '',
}) {
  final override = normalizeApiBaseUrl(configured);
  if (override.isNotEmpty) return override;
  if (web) {
    final origin = normalizeApiBaseUrl(webOrigin);
    if (release && origin.isNotEmpty) return '$origin/api';
    return 'http://localhost:8080/api';
  }
  if (release) {
    throw StateError('API_BASE_URL is required for mobile release builds');
  }
  if (platform == TargetPlatform.android) return 'http://10.0.2.2:8080/api';
  return 'http://localhost:8080/api';
}

String normalizeApiBaseUrl(String value) =>
    value.trim().replaceAll(RegExp(r'/+$'), '');
