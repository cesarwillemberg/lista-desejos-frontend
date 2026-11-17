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
      height: WishlySize.avatar,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < shown.length; index++)
            Align(
              widthFactor: WishlySize.avatarOverlap,
              child: CircleAvatar(
                radius: WishlySize.avatarRadius,
                backgroundColor: index.isEven ? (onDark ? WishlyTokens.inkAvatar : QueroColors.ink) : QueroColors.accent,
                child: Text(
                  shown[index].initials,
                  style: const TextStyle(color: WishlyColor.white, fontSize: WishlyText.xs, fontWeight: FontWeight.w700),
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
        borderRadius: BorderRadius.circular(WishlyRadius.full),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: WishlySpace.s2, vertical: WishlySpace.s1),
        child: Text('Compartilhada', style: TextStyle(color: QueroColors.accent, fontSize: WishlyText.xs, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
