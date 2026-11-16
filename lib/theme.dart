import 'package:material_ui/material_ui.dart';

class QueroColors {
  static const ink = Color(0xFF241C17);
  static const inkSoft = Color(0xFF3C312A);
  static const paper = Color(0xFFF3EEE6);
  static const cream = Color(0xFFFFFCF8);
  static const accent = Color(0xFFE25B2A);
  static const forest = Color(0xFF1E5C45);
  static const muted = Color(0xFF746C62);
  static const line = Color(0xFFE4DCD0);
  static const danger = Color(0xFF9C341F);
  static const note = Color(0xFFF6E7D4);
}

TextStyle fraunces(
  double size, {
  FontWeight weight = FontWeight.w600,
  FontStyle style = FontStyle.normal,
  Color color = QueroColors.ink,
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
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: QueroColors.paper,
    fontFamily: 'Outfit',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: QueroColors.accent,
      onPrimary: Colors.white,
      secondary: QueroColors.forest,
      onSecondary: Colors.white,
      error: QueroColors.danger,
      onError: Colors.white,
      surface: QueroColors.cream,
      onSurface: QueroColors.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Outfit', bodyColor: QueroColors.ink, displayColor: QueroColors.ink),
    splashFactory: NoSplash.splashFactory,
  );
}
