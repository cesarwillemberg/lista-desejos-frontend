import 'package:material_ui/material_ui.dart';

/// Every visual constant for Wishly. Widgets should not invent their own.
abstract final class WishlyColor {
  static const ink = Color(0xFF241C17);
  static const inkSoft = Color(0xFF3C312A);
  static const inkRaised = Color(0xFF3A2F28);
  static const inkLine = Color(0xFF4A3F37);
  static const inkAvatar = Color(0xFF5C4E44);
  static const paper = Color(0xFFF3EEE6);
  static const cream = Color(0xFFFFFCF8);
  static const white = Color(0xFFFFFFFF);
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
  static const shadow = Color(0x1A241C17);
  static const transparent = Color(0x00000000);
}

/// Dark surfaces. The orange accent stays the brand color.
abstract final class WishlyDark {
  static const ink = Color(0xFFF3EEE6);
  static const paper = Color(0xFF1A1410);
  static const cream = Color(0xFF241C17);
  static const white = Color(0xFF2C241E);
  static const muted = Color(0xFFB7ADA3);
  static const line = Color(0xFF8A7D72);
  static const forest = Color(0xFF8FCBB2);
  static const note = Color(0xFF3A2A22);
  static const chip = Color(0xFF4A3024);
  static const danger = Color(0xFFFFB4A2);
  static const image = Color(0xFF3A312A);
  static const placeholder = Color(0xFF322A24);
  static const placeholderLine = Color(0xFF5C4E44);
  static const scrim = Color(0xCC1A1410);
  static const shadow = Color(0x80000000);
}

/// Opacities used by purchased photos, disabled controls, and focus rings.
abstract final class WishlyOpacity {
  static const purchased = 0.45;
  static const placeholder = 0.45;
  static const disabled = 0.55;
  static const focus = 0.18;
  static const hover = 0.06;
}

abstract final class WishlyElevation {
  static const none = 0.0;
}

typedef WishlyTokens = WishlyColor;
typedef QueroColors = WishlyColor;

/// Tailwind-like spacing. s1 is 4px.
abstract final class WishlySpace {
  static const s0 = 0.0;
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
}

abstract final class WishlyRadius {
  static const none = 0.0;
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xl2 = 24.0;
  static const full = 999.0;
}

abstract final class WishlyShadow {
  static const sm = <BoxShadow>[BoxShadow(color: WishlyColor.shadow, blurRadius: 6, offset: Offset(0, 2))];
  static const md = <BoxShadow>[BoxShadow(color: WishlyColor.shadow, blurRadius: 16, offset: Offset(0, 6))];
  static const lg = <BoxShadow>[BoxShadow(color: WishlyColor.shadow, blurRadius: 28, offset: Offset(0, 12))];
  static const xl = <BoxShadow>[BoxShadow(color: WishlyColor.shadow, blurRadius: 40, offset: Offset(0, 18))];
}

abstract final class WishlyText {
  static const xs = 12.0;
  static const sm = 14.0;
  static const base = 16.0;
  static const lg = 18.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
  static const xl5 = 48.0;
  static const xl6 = 64.0;
  static const tracking = 1.2;
  static const tight = 1.05;
  static const snug = 1.15;
  static const body = 1.4;
}

abstract final class WishlyBreak {
  static const sm = 640.0;
  static const md = 768.0;
  static const lg = 1024.0;
  static const xl = 1280.0;
}

abstract final class WishlyIcon {
  static const xs = 12.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
}

abstract final class WishlyDuration {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const pulse = Duration(milliseconds: 900);
}

abstract final class WishlyCard {
  static const maxWidth = 256.0;
  static const imageAspect = 1.55;
  static const radius = WishlyRadius.xl2;
}

abstract final class WishlySize {
  static const tap = WishlySpace.s12;
  static const field = 420.0;
  static const sheet = 460.0;
  static const dialog = 480.0;
  static const dialogTall = 680.0;
  static const listCard = 360.0;
  static const listCardHeight = 220.0;
  static const sidebarMin = 260.0;
  static const sidebarMax = 480.0;
  static const sidebarRail = 76.0;
  static const sidebarDefault = 320.0;
  static const chipRow = 44.0;
  static const headerExtra = 92.0;
  static const collapsedStart = 56.0;
  static const collapsedEnd = 104.0;
  static const avatar = 28.0;
  static const avatarRadius = 13.0;
  static const avatarOverlap = 0.72;
  static const compact = 36.0;
  static const skeletonLine = 180.0;
  static const hairline = 1.0;
  static const ring = 1.4;
  static const stroke = 1.6;
  static const spinner = 2.0;
  static const strokeBold = 2.4;
  static const hatch = 14.0;
}
