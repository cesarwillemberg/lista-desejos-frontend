import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class WishlySkeleton extends StatefulWidget {
  const WishlySkeleton({super.key, this.height = 16, this.width, this.radius = WishlyTokens.radiusSm});

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
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
      decoration: BoxDecoration(color: WishlyTokens.line, borderRadius: BorderRadius.circular(widget.radius)),
      child: SizedBox(height: widget.height, width: widget.width),
    );
    if (reduce) return bar;
    return FadeTransition(opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller), child: bar);
  }
}

class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(WishlyTokens.space4),
      children: [
        const WishlySkeleton(height: 28, width: 180),
        const SizedBox(height: WishlyTokens.space4),
        for (var index = 0; index < cards; index++) ...[
          const WishlySkeleton(height: 120, radius: WishlyTokens.radiusLg),
          const SizedBox(height: WishlyTokens.space3),
        ],
      ],
    );
  }
}
