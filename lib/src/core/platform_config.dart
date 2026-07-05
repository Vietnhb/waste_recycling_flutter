import 'package:flutter/foundation.dart';

String defaultApiBaseUrl() {
  if (kIsWeb) return 'http://localhost:8080/api';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080/api';
  }
  return 'http://localhost:8080/api';
}
