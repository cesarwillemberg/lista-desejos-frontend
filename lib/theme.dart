import 'package:material_ui/material_ui.dart';

import 'theme/tokens.dart';

export 'theme/tokens.dart';

extension WishlyContext on BuildContext {
  bool get wishlyDark => Theme.of(this).brightness == Brightness.dark;

  Color get wishlyInk => wishlyDark ? WishlyDark.ink : WishlyColor.ink;
  Color get wishlyPaper => wishlyDark ? WishlyDark.paper : WishlyColor.paper;
  Color get wishlyCream => wishlyDark ? WishlyDark.cream : WishlyColor.cream;
  Color get wishlyWhite => wishlyDark ? WishlyDark.white : WishlyColor.white;
  Color get wishlyMuted => wishlyDark ? WishlyDark.muted : WishlyColor.muted;
  Color get wishlyLine => wishlyDark ? WishlyDark.line : WishlyColor.line;
  Color get wishlyForest => wishlyDark ? WishlyDark.forest : WishlyColor.forest;
  Color get wishlyNote => wishlyDark ? WishlyDark.note : WishlyColor.note;
  Color get wishlyChip => wishlyDark ? WishlyDark.chip : WishlyColor.chip;
}

TextStyle fraunces(
  double size, {
  FontWeight weight = FontWeight.w600,
  FontStyle style = FontStyle.normal,
  Color? color,
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

class ThemeChoice extends InheritedWidget {
  const ThemeChoice({required this.mode, required this.onChanged, required super.child, super.key});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static ThemeChoice of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeChoice>();
    assert(scope != null, 'ThemeChoice ausente');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeChoice oldWidget) => mode != oldWidget.mode;
}

ThemeData queroTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? WishlyDark.ink : WishlyColor.ink;
  final paper = dark ? WishlyDark.paper : WishlyColor.paper;
  final cream = dark ? WishlyDark.cream : WishlyColor.cream;
  final surfaceText = dark ? WishlyDark.white : WishlyColor.white;
  const accent = WishlyColor.accent;
  final forest = dark ? WishlyDark.forest : WishlyColor.forest;
  final line = dark ? WishlyDark.line : WishlyColor.line;
  final radius = BorderRadius.circular(WishlyRadius.lg);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Outfit',
    visualDensity: VisualDensity.standard,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: WishlyColor.white,
      secondary: forest,
      onSecondary: WishlyColor.white,
      error: WishlyColor.danger,
      onError: WishlyColor.white,
      surface: cream,
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
        foregroundColor: surfaceText,
        minimumSize: const Size(WishlySize.tap, WishlySize.tap),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: WishlyText.base),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(WishlySize.tap, WishlySize.tap), foregroundColor: ink),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: dark ? WishlyDark.chip : WishlyColor.chip,
      checkmarkColor: ink,
      labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: WishlyText.sm),
      side: BorderSide(color: line),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.xl2)),
    ),
    cardTheme: CardThemeData(color: cream, elevation: WishlyElevation.none, margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceText,
      contentPadding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4, vertical: WishlySpace.s3),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
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
