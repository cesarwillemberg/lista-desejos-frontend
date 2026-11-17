import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class PlaceholderArt extends StatelessWidget {
  const PlaceholderArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WishlyTokens.placeholder,
      child: CustomPaint(
        painter: const _HatchPainter(),
        child: Center(
          child: Icon(Icons.local_mall_outlined, size: WishlySize.compact, color: QueroColors.ink.withValues(alpha: WishlyOpacity.placeholder)),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WishlyTokens.placeholderLine
      ..strokeWidth = WishlySize.hairline;
    for (double x = -size.height; x < size.width; x += WishlySize.hatch) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
