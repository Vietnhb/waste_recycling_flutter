import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand palette for the new "Jade Night × Warm Paper" visual language.
///
/// Legacy names such as [primary] and [canvas] intentionally remain available
/// so feature screens can migrate without visual discontinuities.
abstract final class AppPalette {
  static const night = Color(0xFF082F2B);
  static const nightSoft = Color(0xFF123F39);
  static const primaryDark = night;
  static const primary = Color(0xFF0C8C68);
  static const jade = Color(0xFF13B981);
  static const leaf = Color(0xFF74C69D);
  static const lime = Color(0xFFC9F36B);
  static const mint = Color(0xFFE5F7EF);
  static const mintStrong = Color(0xFFC9EFDF);
  static const cream = Color(0xFFFFF8EB);
  static const canvas = Color(0xFFF6F3EA);
  static const surface = Color(0xFFFFFDF8);
  static const surfaceMuted = Color(0xFFEDEFE8);
  static const ink = Color(0xFF132521);
  static const muted = Color(0xFF66756F);
  static const line = Color(0xFFDCE4DC);
  static const amber = Color(0xFFF3B94E);
  static const apricot = Color(0xFFFFC97A);
  static const coral = Color(0xFFF47C66);
  static const sky = Color(0xFF54A9C8);
  static const violet = Color(0xFF8E83D8);
  static const danger = Color(0xFFD94F4F);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const formGap = sm;
  static const sectionGap = lg;
  static const cardPadding = md;
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.mint,
      onPrimaryContainer: AppPalette.night,
      secondary: AppPalette.coral,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFE7DF),
      onSecondaryContainer: Color(0xFF4B211A),
      tertiary: AppPalette.amber,
      onTertiary: AppPalette.ink,
      tertiaryContainer: Color(0xFFFFEDC7),
      onTertiaryContainer: Color(0xFF422B00),
      error: AppPalette.danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFFE4E1),
      onErrorContainer: Color(0xFF4F1515),
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceContainerHighest: AppPalette.surfaceMuted,
      onSurfaceVariant: AppPalette.muted,
      outline: AppPalette.line,
      outlineVariant: Color(0xFFE8ECE6),
      shadow: Color(0x26082F2B),
      scrim: Color(0x99082F2B),
      inverseSurface: AppPalette.night,
      onInverseSurface: AppPalette.cream,
      inversePrimary: AppPalette.lime,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );

    final text = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -2.4,
            height: 0.98,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
            height: 1.02,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1.08,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.12,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        )
        .apply(bodyColor: AppPalette.ink, displayColor: AppPalette.ink);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppPalette.canvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: AppPalette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        labelStyle: const TextStyle(
          color: AppPalette.muted,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppPalette.muted.withValues(alpha: 0.72),
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppPalette.primary,
        suffixIconColor: AppPalette.muted,
        border: inputBorder(AppPalette.line),
        enabledBorder: inputBorder(AppPalette.line),
        focusedBorder: inputBorder(AppPalette.primary, 1.6),
        errorBorder: inputBorder(AppPalette.danger),
        focusedErrorBorder: inputBorder(AppPalette.danger, 1.6),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: AppPalette.line.withValues(alpha: 0.65)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppPalette.line,
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppPalette.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.mintStrong,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppPalette.night
                : AppPalette.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppPalette.primaryDark
                : AppPalette.muted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.mintStrong,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(color: AppPalette.night),
        unselectedIconTheme: const IconThemeData(color: AppPalette.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: AppPalette.night,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: AppPalette.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          backgroundColor: AppPalette.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.line,
          disabledForegroundColor: AppPalette.muted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          foregroundColor: AppPalette.night,
          side: const BorderSide(color: AppPalette.line, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.primaryDark,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surfaceMuted,
        selectedColor: AppPalette.mintStrong,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: const TextStyle(
          color: AppPalette.ink,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      dividerTheme: DividerThemeData(
        color: AppPalette.line.withValues(alpha: 0.8),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.night,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.jade,
        linearTrackColor: AppPalette.mintStrong,
        circularTrackColor: AppPalette.mintStrong,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppPalette.night,
        unselectedLabelColor: AppPalette.muted,
        indicatorColor: AppPalette.jade,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
