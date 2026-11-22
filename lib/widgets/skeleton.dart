import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class WishlySkeleton extends StatefulWidget {
  const WishlySkeleton({super.key, this.height = WishlyText.base, this.width, this.radius = WishlyRadius.sm});

  final double height;
  final double? width;
  final double radius;

  @override
  State<WishlySkeleton> createState() => _WishlySkeletonState();
}

class _WishlySkeletonState extends State<WishlySkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: WishlyDuration.pulse)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final bar = DecoratedBox(
      decoration: BoxDecoration(color: context.wishlyLine, borderRadius: BorderRadius.circular(widget.radius)),
      child: SizedBox(height: widget.height, width: widget.width),
    );
    if (reduce) return bar;
    return FadeTransition(opacity: Tween<double>(begin: WishlyOpacity.placeholder, end: 1).animate(_controller), child: bar);
  }
}

class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(WishlySpace.s4),
      children: [
        const WishlySkeleton(height: WishlyText.xl3, width: WishlySize.field / 2),
        const SizedBox(height: WishlySpace.s4),
        for (var index = 0; index < cards; index++) ...[
          const WishlySkeleton(height: WishlySpace.s16 + WishlySpace.s16, radius: WishlyRadius.xl2),
          const SizedBox(height: WishlySpace.s3),
        ],
      ],
    );
  }
}
