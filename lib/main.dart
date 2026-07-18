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
  final controller = AppController();
  runApp(WasteApp(controller: controller));

  // Paint the branded launch screen immediately. Storage/session restore and
  // media services can initialize in parallel instead of leaving a blank
  // native/web surface before the first Flutter frame.
  await Future.wait([_initializeFirebase(), controller.init()]);
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(options: WasteFirebaseOptions.currentPlatform);
  } catch (error, stack) {
    // The core experience should still open when media upload is unavailable.
    // Upload actions surface their own actionable error when used.
    debugPrint('FIREBASE_INIT_ERROR: $error');
    debugPrintStack(stackTrace: stack);
  }
}
