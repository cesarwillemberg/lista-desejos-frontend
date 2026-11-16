import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class PlaceholderArt extends StatelessWidget {
  const PlaceholderArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE7DFD4),
      child: CustomPaint(
        painter: const _HatchPainter(),
        child: Center(
          child: Icon(Icons.local_mall_outlined, size: 36, color: QueroColors.ink.withValues(alpha: 0.45)),
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
      ..color = const Color(0xFFD9CFC2)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
