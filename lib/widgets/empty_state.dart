import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.icon = Icons.card_giftcard_outlined});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WishlySpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: WishlyIcon.lg * 2, color: WishlyColor.muted),
            const SizedBox(height: WishlySpace.s3),
            Text(title, style: fraunces(WishlyText.xl2), textAlign: TextAlign.center),
            const SizedBox(height: WishlySpace.s2),
            Text(message, style: const TextStyle(color: WishlyColor.muted, fontSize: WishlyText.base, height: WishlyText.body), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
