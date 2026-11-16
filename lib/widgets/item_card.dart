import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../money.dart';
import '../theme.dart';
import 'placeholder_art.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.proxyUrl,
    required this.busy,
    required this.onRefresh,
    required this.onEdit,
    required this.onOpen,
    required this.onDelete,
    this.fillHeight = false,
    this.readOnly = false,
    this.onReserve,
    this.onUnreserve,
    this.imageHeaders,
  });

  final WishItem item;
  final String proxyUrl;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool fillHeight;
  final bool readOnly;
  final VoidCallback? onReserve;
  final VoidCallback? onUnreserve;
  final Map<String, String>? imageHeaders;

  @override
  Widget build(BuildContext context) {
    final details = _CardDetails(
      item: item,
      busy: busy,
      fillHeight: fillHeight,
      readOnly: readOnly,
      onRefresh: onRefresh,
      onEdit: onEdit,
      onOpen: onOpen,
      onDelete: onDelete,
      onReserve: onReserve,
      onUnreserve: onUnreserve,
    );
    return Material(
      color: QueroColors.cream,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProductImage(item: item, proxyUrl: proxyUrl, headers: imageHeaders),
                if (busy)
                  const ColoredBox(
                    color: Color(0x66FFFCF8),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: QueroColors.ink)),
                  ),
              ],
            ),
          ),
          if (fillHeight) Expanded(child: details) else details,
        ],
      ),
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.item,
    required this.busy,
    required this.fillHeight,
    required this.onRefresh,
    required this.onEdit,
    required this.onOpen,
    required this.onDelete,
    required this.readOnly,
    this.onReserve,
    this.onUnreserve,
  });

  final WishItem item;
  final bool busy;
  final bool fillHeight;
  final bool readOnly;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onReserve;
  final VoidCallback? onUnreserve;

  @override
  Widget build(BuildContext context) {
    final price = item.price == null ? 'Preço indisponível' : formatMoney(item.price!, item.currency);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (item.store ?? 'Loja').toUpperCase(),
            style: const TextStyle(color: QueroColors.accent, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: fraunces(20, height: 1.15)),
          const SizedBox(height: 10),
          Text(
            price,
            style: item.price == null
                ? const TextStyle(color: QueroColors.muted, fontSize: 16, fontWeight: FontWeight.w500)
                : fraunces(26, color: QueroColors.forest),
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
          if (fillHeight) const Spacer(),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            children: [
              if (!readOnly) ...[
                _Action(label: 'Atualizar', onPressed: busy ? null : onRefresh),
                _Action(label: 'Editar', onPressed: busy ? null : onEdit),
              ],
              _Action(label: 'Abrir', onPressed: onOpen),
              if (!readOnly) _Action(label: 'Excluir', onPressed: busy ? null : onDelete, danger: true),
              if (readOnly && !item.reserved && onReserve != null) _Action(label: 'Reservar', onPressed: busy ? null : onReserve),
              if (item.reservedByMe && onUnreserve != null) _Action(label: 'Desmarcar', onPressed: busy ? null : onUnreserve),
              if (!readOnly && item.reserved && onUnreserve != null) _Action(label: 'Liberar', onPressed: busy ? null : onUnreserve),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onPressed, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: danger ? QueroColors.danger : QueroColors.ink,
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
    return Image.network(
      proxyUrl,
      headers: headers,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        return Image.network(
          item.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const PlaceholderArt(),
        );
      },
    );
  }
}
