import 'package:flutter/material.dart';

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
          title: 'GreenLoop',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppPalette.primary,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppPalette.canvas,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              backgroundColor: AppPalette.canvas,
              foregroundColor: AppPalette.ink,
              titleTextStyle: TextStyle(
                color: AppPalette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppPalette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppPalette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 1.4,
                ),
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppPalette.line),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: AppPalette.line),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: AppPalette.line),
            ),
          ),
          home: controller.booting
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                )
              : HomeScreen(controller: controller),
        );
      },
    );
  }
}
