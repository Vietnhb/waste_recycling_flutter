import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../controllers/app_controller.dart';
import '../home/home_screen.dart';
import '../shared/widgets.dart';

class WasteApp extends StatelessWidget {
  const WasteApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tái Chế Xanh',
          theme: AppTheme.light(),
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [Locale('vi', 'VN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: controller.booting
              ? const _AppLaunchView()
              : HomeScreen(controller: controller),
        );
      },
    );
  }
}

class _AppLaunchView extends StatelessWidget {
  const _AppLaunchView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppPalette.cream,
      body: SafeArea(child: AppLoadingView(label: 'Đang khởi động…')),
    );
  }
}
