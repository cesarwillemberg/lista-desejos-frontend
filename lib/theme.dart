import 'package:material_ui/material_ui.dart';

import 'theme/tokens.dart';

export 'theme/tokens.dart';

TextStyle fraunces(
  double size, {
  FontWeight weight = FontWeight.w600,
  FontStyle style = FontStyle.normal,
  Color color = WishlyColor.ink,
  double height = WishlyText.tight,
}) {
  return TextStyle(
    fontFamily: 'Fraunces',
    fontFamilyFallback: const ['Georgia', 'serif'],
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    color: color,
    height: height,
  );
}

ThemeData queroTheme() {
  const ink = WishlyColor.ink;
  const accent = WishlyColor.accent;
  final radius = BorderRadius.circular(WishlyRadius.lg);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: WishlyColor.paper,
    fontFamily: 'Outfit',
    visualDensity: VisualDensity.standard,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: WishlyColor.white,
      secondary: WishlyColor.forest,
      onSecondary: WishlyColor.white,
      error: WishlyColor.danger,
      onError: WishlyColor.white,
      surface: WishlyColor.cream,
      onSurface: ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Outfit', bodyColor: ink, displayColor: ink),
    splashFactory: InkSparkle.splashFactory,
    focusColor: accent.withValues(alpha: WishlyOpacity.focus),
    hoverColor: accent.withValues(alpha: WishlyOpacity.hover),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(WishlySize.tap, WishlySize.tap),
        foregroundColor: ink,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: WishlyColor.white,
        minimumSize: const Size(WishlySize.tap, WishlySize.tap),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: WishlyText.base),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(WishlySize.tap, WishlySize.tap), foregroundColor: ink),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: WishlyColor.chip,
      checkmarkColor: ink,
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: WishlyText.sm),
      side: const BorderSide(color: WishlyColor.line),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: WishlyColor.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.xl2)),
    ),
    cardTheme: const CardThemeData(color: WishlyColor.cream, elevation: WishlyElevation.none, margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WishlyColor.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4, vertical: WishlySpace.s3),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: WishlyColor.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: WishlyColor.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: accent, width: WishlySize.stroke)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
