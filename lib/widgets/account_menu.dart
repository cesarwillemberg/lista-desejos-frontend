import 'package:material_ui/material_ui.dart';

import '../session.dart';
import '../theme.dart';
import 'avatar.dart';

void openSettings(BuildContext context) {
  Navigator.of(context).pushNamed('/configuracoes');
}

class AccountBar extends StatelessWidget {
  const AccountBar({super.key, this.onDark = true, this.padForSafeArea = false});

  final bool onDark;
  final bool padForSafeArea;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.user;
    final name = user?.name ?? 'Minha conta';
    final nameColor = onDark ? QueroColors.cream : context.wishlyInk;
    final hintColor = onDark ? WishlyTokens.onInkMuted : context.wishlyMuted;
    final row = InkWell(
      onTap: () => openSettings(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s3, WishlySpace.s3, WishlySpace.s3),
        child: Row(
          children: [
            WishlyAvatar(
              label: name,
              userId: user?.id,
              hasAvatar: user?.hasAvatar ?? false,
              version: user?.avatarAt,
              api: session.api,
              radius: 20,
            ),
            const SizedBox(width: WishlySpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: nameColor, fontWeight: FontWeight.w700)),
                  Text('Configurações', style: TextStyle(color: hintColor, fontSize: WishlyText.sm, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: nameColor),
          ],
        ),
      ),
    );
    final bar = Material(
      color: onDark ? QueroColors.ink : context.wishlyPaper,
      child: row,
    );
    if (!padForSafeArea) return bar;
    return SafeArea(top: false, child: bar);
  }
}

List<PopupMenuEntry<String>> accountMenuEntries(BuildContext context) {
  final session = SessionScope.of(context);
  final user = session.user;
  final name = user?.name ?? 'Minha conta';
  return [
    PopupMenuItem(
      value: 'account',
      height: 68,
      child: Row(
        children: [
          WishlyAvatar(
            label: name,
            userId: user?.id,
            hasAvatar: user?.hasAvatar ?? false,
            version: user?.avatarAt,
            api: session.api,
            radius: 16,
          ),
          const SizedBox(width: WishlySpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minha conta', style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.xs, fontWeight: FontWeight.w700)),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    ),
    const PopupMenuItem(
      value: 'settings',
      child: Row(
        children: [
          Icon(Icons.settings_outlined, size: WishlyIcon.lg),
          SizedBox(width: WishlySpace.s3),
          Text('Configurações'),
        ],
      ),
    ),
  ];
}
