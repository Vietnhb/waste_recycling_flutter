import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'src/controllers/app_controller.dart';
import 'src/core/firebase_options.dart';
import 'src/ui/app/waste_app.dart';

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
      color: const Color(0xFFF7F8F3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            kDebugMode
                ? details.exceptionAsString()
                : 'Có lỗi khi tải màn hình. Hãy thử tải lại.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF18231C)),
          ),
        ),
      ),
    );
  };
  await Firebase.initializeApp(options: WasteFirebaseOptions.currentPlatform);
  final controller = AppController();
  await controller.init();
  runApp(WasteApp(controller: controller));
}
