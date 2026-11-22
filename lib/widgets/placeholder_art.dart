import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class PlaceholderArt extends StatelessWidget {
  const PlaceholderArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.wishlyPlaceholder,
      child: CustomPaint(
        painter: _HatchPainter(context.wishlyPlaceholderLine),
        child: Center(
          child: Icon(Icons.local_mall_outlined, size: WishlySize.compact, color: context.wishlyInk.withValues(alpha: WishlyOpacity.placeholder)),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = WishlySize.hairline;
    for (double x = -size.height; x < size.width; x += WishlySize.hatch) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => oldDelegate.color != color;
}
