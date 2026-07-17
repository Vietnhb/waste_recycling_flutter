import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'src/controllers/app_controller.dart';
import 'src/core/firebase_options.dart';
import 'src/ui/app/waste_app.dart';
import 'src/ui/shared/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PLATFORM_ERROR: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };
  ErrorWidget.builder = (details) {
    return Material(
      color: AppPalette.cream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            kDebugMode
                ? details.exceptionAsString()
                : 'Có lỗi khi tải màn hình. Hãy thử tải lại.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppPalette.ink),
          ),
        ),
      ),
    );
  };
  try {
    await Firebase.initializeApp(options: WasteFirebaseOptions.currentPlatform);
  } catch (error, stack) {
    // The core experience should still open when Firebase is unavailable.
    // Features that upload media will surface their own actionable error.
    debugPrint('FIREBASE_INIT_ERROR: $error');
    debugPrintStack(stackTrace: stack);
  }
  final controller = AppController();
  await controller.init();
  runApp(WasteApp(controller: controller));
}
