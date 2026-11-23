import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../theme.dart';

class WishlyAvatar extends StatelessWidget {
  const WishlyAvatar({
    super.key,
    required this.label,
    this.userId,
    this.hasAvatar = false,
    this.version,
    this.radius = WishlySize.avatarRadius,
    this.api,
  });

  final String label;
  final String? userId;
  final bool hasAvatar;
  final String? version;
  final double radius;
  final QueroApi? api;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);
    final color = _palette(label);
    final photo = hasAvatar && userId != null && api != null
        ? NetworkImage(api!.avatarUrl(userId!, version: version))
        : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: photo,
      child: Text(
        initials,
        style: TextStyle(color: WishlyColor.white, fontSize: radius * 0.72, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _initials(String label) {
  final parts = label.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  final cleaned = label.replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ]'), '');
  return (cleaned.isEmpty ? '?' : cleaned.substring(0, cleaned.length >= 2 ? 2 : 1)).toUpperCase();
}

Color _palette(String label) {
  const colors = [WishlyColor.accent, WishlyColor.forest, WishlyColor.inkAvatar, WishlyColor.danger];
  var hash = 0;
  for (final unit in label.codeUnits) {
    hash = (hash + unit) % colors.length;
  }
  return colors[hash];
}
