import 'package:material_ui/material_ui.dart';

/// Wishly visual tokens. Hex values live only here.
class WishlyTokens {
  static const ink = Color(0xFF241C17);
  static const inkSoft = Color(0xFF3C312A);
  static const inkRaised = Color(0xFF3A2F28);
  static const inkLine = Color(0xFF4A3F37);
  static const inkAvatar = Color(0xFF5C4E44);
  static const paper = Color(0xFFF3EEE6);
  static const cream = Color(0xFFFFFCF8);
  static const accent = Color(0xFFE25B2A);
  static const forest = Color(0xFF1E5C45);
  static const muted = Color(0xFF746C62);
  static const line = Color(0xFFE4DCD0);
  static const danger = Color(0xFF9C341F);
  static const note = Color(0xFFF6E7D4);
  static const chip = Color(0xFFF3D2C4);
  static const onInk = Color(0xFFD7CDC2);
  static const onInkMuted = Color(0xFFB7ADA3);
  static const onInkLabel = Color(0xFFD9CFC4);
  static const onInkHint = Color(0xFFB3A79C);
  static const onInkDanger = Color(0xFFFFB4A2);
  static const badge = Color(0xFFF6DDD2);
  static const badgeOnInk = Color(0xFF4A3024);
  static const placeholder = Color(0xFFE7DFD4);
  static const placeholderLine = Color(0xFFD9CFC2);
  static const scrim = Color(0x66FFFCF8);

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;
  static const radiusXl = 22.0;

  static const elevation0 = 0.0;
  static const elevation1 = 1.0;

  static const typeDisplay = 32.0;
  static const typeTitle = 24.0;
  static const typeBody = 16.0;
  static const typeCaption = 13.0;

  static const motionFast = Duration(milliseconds: 160);
}

/// Existing name kept so screens keep compiling against one palette.
typedef QueroColors = WishlyTokens;

TextStyle fraunces(
  double size, {
  FontWeight weight = FontWeight.w600,
  FontStyle style = FontStyle.normal,
  Color color = WishlyTokens.ink,
  double height = 1.05,
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
  const ink = WishlyTokens.ink;
  const accent = WishlyTokens.accent;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: WishlyTokens.paper,
    fontFamily: 'Outfit',
    visualDensity: VisualDensity.standard,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      secondary: WishlyTokens.forest,
      onSecondary: Colors.white,
      error: WishlyTokens.danger,
      onError: Colors.white,
      surface: WishlyTokens.cream,
      onSurface: ink,
    ),
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyTokens.radiusMd));
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Outfit', bodyColor: ink, displayColor: ink),
    splashFactory: InkSparkle.splashFactory,
    focusColor: accent.withValues(alpha: 0.18),
    hoverColor: accent.withValues(alpha: 0.06),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ink, tapTargetSize: MaterialTapTargetSize.padded),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ink),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: WishlyTokens.chip,
      checkmarkColor: ink,
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
      side: const BorderSide(color: WishlyTokens.line),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: WishlyTokens.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyTokens.radiusLg)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WishlyTokens.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WishlyTokens.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accent, width: 1.6)),
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
