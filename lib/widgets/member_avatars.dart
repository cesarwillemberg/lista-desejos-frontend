import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../theme.dart';

class MemberAvatars extends StatelessWidget {
  const MemberAvatars({super.key, required this.members, this.onDark = false});

  final List<ListMember> members;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(5).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < shown.length; index++)
            Align(
              widthFactor: 0.72,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: index.isEven ? (onDark ? WishlyTokens.inkAvatar : QueroColors.ink) : QueroColors.accent,
                child: Text(
                  shown[index].initials,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SharedBadge extends StatelessWidget {
  const SharedBadge({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onDark ? WishlyTokens.badgeOnInk : WishlyTokens.badge,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text('Compartilhada', style: TextStyle(color: QueroColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
