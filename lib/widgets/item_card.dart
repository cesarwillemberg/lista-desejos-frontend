import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../money.dart';
import '../scrape_copy.dart';
import '../session.dart';
import '../theme.dart';
import 'avatar.dart';
import 'placeholder_art.dart';

const _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.proxyUrl,
    required this.busy,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    this.readOnly = false,
    this.onReserve,
    this.onUnreserve,
    this.onTogglePurchased,
    this.imageHeaders,
    this.fillHeight = false,
  });

  final WishItem item;
  final String proxyUrl;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool readOnly;
  final VoidCallback? onReserve;
  final VoidCallback? onUnreserve;
  final VoidCallback? onTogglePurchased;
  final Map<String, String>? imageHeaders;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final details = _CardDetails(
      item: item,
      busy: busy,
      readOnly: readOnly,
      onRefresh: onRefresh,
      onEdit: onEdit,
      onDelete: onDelete,
      onReserve: onReserve,
      onUnreserve: onUnreserve,
      onTogglePurchased: onTogglePurchased,
      showActions: !fillHeight,
    );
    final actions = _CardActions(
      item: item,
      busy: busy,
      readOnly: readOnly,
      onRefresh: onRefresh,
      onEdit: onEdit,
      onDelete: onDelete,
      onUnreserve: onUnreserve,
      onTogglePurchased: onTogglePurchased,
    );
    final waiting = item.status == 'pending';
    Widget image = _ProductImage(item: item, proxyUrl: proxyUrl, headers: imageHeaders);
    if (item.purchased) {
      image = Opacity(opacity: WishlyOpacity.purchased, child: ColorFiltered(colorFilter: _grey, child: image));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(WishlyCard.radius)),
        boxShadow: [BoxShadow(color: context.wishlyDark ? WishlyDark.shadow : WishlyColor.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
      color: context.wishlyCream,
      borderRadius: BorderRadius.circular(WishlyCard.radius),
      clipBehavior: Clip.antiAlias,
      child: fillHeight
          ? _PinBottom(
              top: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cardImage(context, image, waiting),
                  details,
                ],
              ),
              bottom: Padding(
                padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s2, WishlySpace.s4, WishlySpace.s2),
                child: actions,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _cardImage(context, image, waiting),
                details,
              ],
            ),
      ),
    );
  }

  Widget _cardImage(BuildContext context, Widget image, bool waiting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WishlySpace.s3, WishlySpace.s3, WishlySpace.s3, WishlySpace.s0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WishlyRadius.xl),
        child: AspectRatio(
          aspectRatio: WishlyCard.imageAspect,
          child: ColoredBox(
            color: context.wishlyImage,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _StoreLink(url: item.url, child: image),
                if (item.purchased)
                  const Positioned(
                    left: WishlySpace.s3,
                    top: WishlySpace.s3,
                    child: _BoughtBadge(),
                  ),
                if (busy || waiting)
                  ColoredBox(
                    color: context.wishlyScrim,
                    child: Center(child: CircularProgressIndicator(strokeWidth: WishlySize.strokeBold, color: context.wishlyInk)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _detailLine(WishItem item) {
  final parts = <String>[
    if (item.colorName != null && item.colorName!.isNotEmpty) item.colorName!,
    if (item.sizeLabel != null && item.sizeLabel!.isNotEmpty) item.sizeLabel!,
    if (item.voltage != null && item.voltage!.isNotEmpty) item.voltage!,
    if (item.quantity != null) '×${item.quantity}',
  ];
  return parts.join(' · ');
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'muito':
      return 'Quero muito';
    case 'talvez':
      return 'Talvez';
    default:
      return 'Quero';
  }
}

Color _priorityColor(BuildContext context, String priority) {
  switch (priority) {
    case 'muito':
      return WishlyColor.accent;
    case 'talvez':
      return context.wishlyMuted;
    default:
      return context.wishlyForest;
  }
}

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.item});
  final WishItem item;

  @override
  Widget build(BuildContext context) {
    final points = item.history.isEmpty && item.price != null ? [item.price!] : item.history;
    final low = points.isEmpty ? null : points.reduce((a, b) => a < b ? a : b);
    final high = points.isEmpty ? null : points.reduce((a, b) => a > b ? a : b);
    return AlertDialog(
      backgroundColor: context.wishlyCream,
      title: Text('Histórico de preço', style: fraunces(WishlyText.xl2)),
      content: SizedBox(
        width: WishlySize.field,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: WishlySpace.s16, width: double.infinity, child: CustomPaint(painter: _SparkPainter(points, context.wishlyForest))),
            const SizedBox(height: WishlySpace.s3),
            if (low != null) Text('Menor ${formatMoney(low, item.currency)}', style: TextStyle(color: context.wishlyForest, fontWeight: FontWeight.w700)),
            if (high != null) Text('Maior ${formatMoney(high, item.currency)}', style: TextStyle(color: context.wishlyMuted)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final low = points.reduce((a, b) => a < b ? a : b);
    final high = points.reduce((a, b) => a > b ? a : b);
    final span = (high - low).abs() < 0.01 ? 1.0 : high - low;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - ((points[i] - low) / span) * (size.height - WishlySpace.s2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = WishlySize.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.points != points || oldDelegate.color != color;
}

class _BoughtBadge extends StatelessWidget {
  const _BoughtBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: context.wishlyInk, borderRadius: BorderRadius.circular(WishlyRadius.full)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s3, vertical: WishlySpace.s1),
        child: Text('Comprado', style: TextStyle(color: context.wishlyPaper, fontSize: WishlyText.xs, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.item,
    required this.busy,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.readOnly,
    this.onReserve,
    this.onUnreserve,
    this.onTogglePurchased,
    this.showActions = true,
  });

  final WishItem item;
  final bool busy;
  final bool readOnly;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReserve;
  final VoidCallback? onUnreserve;
  final VoidCallback? onTogglePurchased;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final price = item.status == 'pending' && item.price == null ? 'Lendo o preço…' : (item.price == null ? 'Preço indisponível' : formatMoney(item.price!, item.currency));
    final priceStyle = item.price == null
        ? TextStyle(color: context.wishlyMuted, fontSize: WishlyText.base, fontWeight: FontWeight.w500)
        : fraunces(WishlyText.xl2, color: item.purchased ? context.wishlyMuted : context.wishlyForest);
    return Padding(
      padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s4, WishlySpace.s4, WishlySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreLink(
            url: item.url,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    (item.store ?? 'Loja').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: QueroColors.accent, fontSize: WishlyText.xs, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: WishlySpace.s1),
                const Icon(Icons.open_in_new, size: WishlyIcon.xs, color: QueroColors.accent),
              ],
            ),
          ),
          const SizedBox(height: WishlySpace.s2),
          _StoreLink(
            url: item.url,
            underline: true,
            child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: fraunces(WishlyText.xl, height: WishlyText.snug)),
          ),
          if (item.addedByLabel != null && item.addedByLabel!.isNotEmpty) ...[
            const SizedBox(height: WishlySpace.s1),
            Row(
              children: [
                if (item.addedById != null)
                  Padding(
                    padding: const EdgeInsets.only(right: WishlySpace.s1),
                    child: WishlyAvatar(
                      label: item.addedByLabel!,
                      userId: item.addedById,
                      hasAvatar: item.addedByHasAvatar,
                      version: item.addedByAvatarAt,
                      api: SessionScope.of(context).api,
                      radius: 8,
                    ),
                  ),
                Expanded(
                  child: Text(
                    'adicionado por ${item.addedByLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.xs),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: WishlySpace.s3),
          Text(
            price,
            style: item.purchased ? priceStyle.copyWith(decoration: TextDecoration.lineThrough, decorationColor: context.wishlyMuted) : priceStyle,
          ),
          const SizedBox(height: WishlySpace.s2),
          Wrap(
            spacing: WishlySpace.s2,
            runSpacing: WishlySpace.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: _priorityColor(context, item.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(WishlyRadius.full)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s2, vertical: WishlySpace.s1),
                  child: Text(_priorityLabel(item.priority), style: TextStyle(color: _priorityColor(context, item.priority), fontSize: WishlyText.xs, fontWeight: FontWeight.w700)),
                ),
              ),
              if (item.priceDrop != null)
                InkWell(
                  onTap: () => showDialog<void>(context: context, builder: (context) => _HistoryDialog(item: item)),
                  child: Text('↓ ${formatMoney(item.priceDrop!, item.currency)}', style: TextStyle(color: context.wishlyForest, fontSize: WishlyText.sm, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: WishlySpace.s2),
              child: Text(item.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.sm, height: WishlyText.body)),
            ),
          if (_detailLine(item).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: WishlySpace.s1),
              child: Text(_detailLine(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.xs)),
            ),
          if (item.message != null && item.status != 'ok') ...[
            const SizedBox(height: WishlySpace.s3),
            _ScrapeNote(message: item.message!),
          ],
          if (item.reserved) ...[
            const SizedBox(height: WishlySpace.s2),
            Row(
              children: [
                if (item.reservedById != null || item.reservedByMe)
                  Padding(
                    padding: const EdgeInsets.only(right: WishlySpace.s2),
                    child: WishlyAvatar(
                      label: item.reservedByMe
                          ? (SessionScope.of(context).user?.name ?? item.reservedLabel ?? 'Você')
                          : (item.reservedLabel ?? 'Reservado'),
                      userId: item.reservedById ?? SessionScope.of(context).user?.id,
                      hasAvatar: item.reservedById != null
                          ? item.reservedByHasAvatar
                          : (SessionScope.of(context).user?.hasAvatar ?? false),
                      version: item.reservedByAvatarAt ?? SessionScope.of(context).user?.avatarAt,
                      api: SessionScope.of(context).api,
                      radius: 8,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.reservedByMe
                        ? 'Você marcou este item'
                        : (item.reservedLabel == null ? 'Reservado' : 'Reservado por ${item.reservedLabel}'),
                    style: TextStyle(color: context.wishlyForest, fontWeight: FontWeight.w600, fontSize: WishlyText.sm),
                  ),
                ),
              ],
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: WishlySpace.s2),
            _CardActions(
              item: item,
              busy: busy,
              readOnly: readOnly,
              onRefresh: onRefresh,
              onEdit: onEdit,
              onDelete: onDelete,
              onUnreserve: onUnreserve,
              onTogglePurchased: onTogglePurchased,
              onReserve: onReserve,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrapeNote extends StatelessWidget {
  const _ScrapeNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final short = conciseScrapeMessage(message);
    return Tooltip(
      message: message,
      child: InkWell(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: context.wishlyCream,
              content: Text(message, style: TextStyle(color: context.wishlyInk, height: WishlyText.body)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
            ),
          );
        },
        borderRadius: BorderRadius.circular(WishlyRadius.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.wishlyNote, borderRadius: BorderRadius.circular(WishlyRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s3, vertical: WishlySpace.s2),
            child: Text(
              short,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.wishlyInk, fontSize: WishlyText.sm, height: WishlyText.body),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.item,
    required this.busy,
    required this.readOnly,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    this.onReserve,
    this.onUnreserve,
    this.onTogglePurchased,
  });

  final WishItem item;
  final bool busy;
  final bool readOnly;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReserve;
  final VoidCallback? onUnreserve;
  final VoidCallback? onTogglePurchased;

  @override
  Widget build(BuildContext context) {
    final retry = !readOnly && offerScrapeRetry(status: item.status, message: item.message);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (retry)
          Align(
            alignment: Alignment.centerLeft,
            child: _Action(label: 'Tentar de novo', onPressed: busy ? null : onRefresh),
          ),
        Row(
          children: [
            if (!readOnly && onTogglePurchased != null) _BuyToggle(purchased: item.purchased, onPressed: busy ? null : onTogglePurchased),
            const Spacer(),
            if (!readOnly)
              PopupMenuButton<String>(
                tooltip: 'Ações',
                icon: const Icon(Icons.more_vert, size: WishlyIcon.md),
                padding: EdgeInsets.zero,
                onSelected: (value) => switch (value) {
                  'refresh' => onRefresh(),
                  'edit' => onEdit(),
                  'delete' => onDelete(),
                  'release' => onUnreserve?.call(),
                  _ => null,
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'refresh', child: Text('Atualizar')),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  if (item.reserved && onUnreserve != null) const PopupMenuItem(value: 'release', child: Text('Liberar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: context.wishlyDanger))),
                ],
              )
            else ...[
              if (!item.reserved && onReserve != null) _Action(label: 'Eu vou dar esse', onPressed: busy ? null : onReserve),
              if (item.reservedByMe && onUnreserve != null) _Action(label: 'Desmarcar', onPressed: busy ? null : onUnreserve),
            ],
          ],
        ),
      ],
    );
  }
}

class _StoreLink extends StatefulWidget {
  const _StoreLink({required this.url, required this.child, this.underline = false});

  final String url;
  final Widget child;
  final bool underline;

  @override
  State<_StoreLink> createState() => _StoreLinkState();
}

class _StoreLinkState extends State<_StoreLink> {
  var _hover = false;

  Future<void> _open() async {
    if (Uri.tryParse(widget.url) case final uri?) {
      await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.underline
        ? DefaultTextStyle.merge(
            style: TextStyle(decoration: _hover ? TextDecoration.underline : TextDecoration.none),
            child: widget.child,
          )
        : widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: kIsWeb ? (_) => setState(() => _hover = true) : null,
      onExit: kIsWeb ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(onTap: _open, child: linked),
    );
  }
}

class _BuyToggle extends StatelessWidget {
  const _BuyToggle({required this.purchased, required this.onPressed});

  final bool purchased;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = context.wishlyInk;
    final forest = context.wishlyForest;
    final onFilled = context.wishlyOnForest;
    return Tooltip(
      message: purchased ? 'Desmarcar comprado' : 'Marcar como comprado',
      child: Material(
        color: purchased ? forest : WishlyColor.transparent,
        shape: StadiumBorder(side: BorderSide(color: purchased ? forest : context.wishlyLine)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s3, vertical: WishlySpace.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(purchased ? Icons.check_circle : Icons.check_circle_outline, size: WishlyIcon.sm, color: purchased ? onFilled : ink),
                const SizedBox(width: WishlySpace.s1),
                Text(
                  purchased ? 'Comprado' : 'Comprar',
                  style: TextStyle(fontSize: WishlyText.sm, fontWeight: FontWeight.w700, color: purchased ? onFilled : ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ItemWrap extends StatelessWidget {
  const ItemWrap({super.key, required this.count, required this.itemBuilder});

  final int count;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = WishlySpace.s3;
        const maxCard = WishlyCard.maxWidth;
        final estimated = (constraints.maxWidth / maxCard).floor();
        final columns = estimated < 1 ? 1 : estimated;
        final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          children: [
            for (var start = 0; start < count; start += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = start; index < math.min(start + columns, count); index++) ...[
                        if (index > start) const SizedBox(width: gap),
                        SizedBox(width: width, child: itemBuilder(index)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = context.wishlyInk;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: WishlyColor.transparent,
        side: BorderSide(color: context.wishlyLine),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s3, vertical: WishlySpace.s2),
        minimumSize: const Size(WishlySpace.s0, WishlySize.tap),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: TextStyle(fontSize: WishlyText.sm, fontWeight: FontWeight.w700, color: ink)),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item, required this.proxyUrl, this.headers});

  final WishItem item;
  final String proxyUrl;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) return const PlaceholderArt();
    return Padding(
      padding: const EdgeInsets.all(WishlySpace.s3),
      child: Image.network(
          proxyUrl,
          headers: headers,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (context, error, stack) {
            return Image.network(
              item.imageUrl!,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (context, error, stack) => const PlaceholderArt(),
            );
          },
        ),
    );
  }
}

class _PinBottom extends MultiChildRenderObjectWidget {
  _PinBottom({required Widget top, required Widget bottom}) : super(children: [top, bottom]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPinBottom();
}

class _PinParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays the footer at the bottom when the parent gives a height, and reports
/// the content height as its intrinsic height so a row can match the tallest card.
class _RenderPinBottom extends RenderBox with ContainerRenderObjectMixin<RenderBox, _PinParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PinParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PinParentData) child.parentData = _PinParentData();
  }

  RenderBox get _top => firstChild!;
  RenderBox get _bottom => childAfter(firstChild!)!;

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _top.getMaxIntrinsicHeight(width) + _bottom.getMaxIntrinsicHeight(width);
  }

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicWidth(double height) {
    return math.max(_top.getMaxIntrinsicWidth(height), _bottom.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => computeMaxIntrinsicWidth(height);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    _bottom.layout(loose, parentUsesSize: true);
    final footer = _bottom.size.height;
    if (constraints.hasTightHeight) {
      final height = constraints.maxHeight;
      final body = math.max(0.0, height - footer);
      _top.layout(BoxConstraints.tightFor(width: width, height: body), parentUsesSize: true);
      (_top.parentData! as _PinParentData).offset = Offset.zero;
      (_bottom.parentData! as _PinParentData).offset = Offset(0, height - footer);
      size = Size(width, height);
      return;
    }
    _top.layout(loose, parentUsesSize: true);
    (_top.parentData! as _PinParentData).offset = Offset.zero;
    (_bottom.parentData! as _PinParentData).offset = Offset(0, _top.size.height);
    size = constraints.constrain(Size(width, _top.size.height + footer));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
