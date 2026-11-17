import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../money.dart';
import '../theme.dart';
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
    );
    Widget image = _ProductImage(item: item, proxyUrl: proxyUrl, headers: imageHeaders);
    if (item.purchased) {
      image = Opacity(opacity: 0.45, child: ColorFiltered(colorFilter: _grey, child: image));
    }
    return Material(
      color: QueroColors.cream,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _StoreLink(url: item.url, child: image),
                if (item.purchased)
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: _BoughtBadge(),
                  ),
                if (busy)
                  const ColoredBox(
                    color: WishlyTokens.scrim,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: QueroColors.ink)),
                  ),
              ],
            ),
          ),
          details,
        ],
      ),
    );
  }
}

class _BoughtBadge extends StatelessWidget {
  const _BoughtBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: QueroColors.ink, borderRadius: BorderRadius.circular(99)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text('Comprado', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
    final price = item.price == null ? 'Preço indisponível' : formatMoney(item.price!, item.currency);
    final priceStyle = item.price == null
        ? const TextStyle(color: QueroColors.muted, fontSize: 16, fontWeight: FontWeight.w500)
        : fraunces(26, color: item.purchased ? QueroColors.muted : QueroColors.forest);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                    style: const TextStyle(color: QueroColors.accent, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new, size: 13, color: QueroColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _StoreLink(
            url: item.url,
            underline: true,
            child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: fraunces(20, height: 1.15)),
          ),
          if (item.addedByLabel != null && item.addedByLabel!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'adicionado por ${item.addedByLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: QueroColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            price,
            style: item.purchased ? priceStyle.copyWith(decoration: TextDecoration.lineThrough, decorationColor: QueroColors.muted) : priceStyle,
          ),
          if (item.message != null && item.status != 'ok') ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(color: QueroColors.note, borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  item.message!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: QueroColors.ink, fontSize: 12.5, height: 1.35),
                ),
              ),
            ),
          ],
          if (item.reserved) ...[
            const SizedBox(height: 8),
            Text(
              item.reservedByMe
                  ? 'Você marcou este item'
                  : (item.reservedLabel == null ? 'Reservado' : 'Reservado por ${item.reservedLabel}'),
              style: const TextStyle(color: QueroColors.forest, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (!readOnly && onTogglePurchased != null) _BuyToggle(purchased: item.purchased, onPressed: busy ? null : onTogglePurchased),
              const Spacer(),
              if (!readOnly)
                PopupMenuButton<String>(
                  tooltip: 'Ações',
                  icon: const Icon(Icons.more_vert, size: 20),
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
                    const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: QueroColors.danger))),
                  ],
                )
              else ...[
                if (!item.reserved && onReserve != null) _Action(label: 'Reservar', onPressed: busy ? null : onReserve),
                if (item.reservedByMe && onUnreserve != null) _Action(label: 'Desmarcar', onPressed: busy ? null : onUnreserve),
              ],
            ],
          ),
        ],
      ),
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
    final color = purchased ? QueroColors.forest : QueroColors.ink;
    return Tooltip(
      message: purchased ? 'Desmarcar comprado' : 'Marcar como comprado',
      child: Material(
        color: purchased ? QueroColors.forest : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: purchased ? QueroColors.forest : QueroColors.line)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(purchased ? Icons.check_circle : Icons.check_circle_outline, size: 16, color: purchased ? Colors.white : color),
                const SizedBox(width: 4),
                Text(
                  purchased ? 'Comprado' : 'Comprar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: purchased ? Colors.white : color),
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
        const gap = 12.0;
        const maxCard = 252.0;
        final estimated = (constraints.maxWidth / maxCard).floor();
        final columns = estimated < 1 ? 1 : estimated;
        final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < count; index++) SizedBox(width: width, child: itemBuilder(index)),
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
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: QueroColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
