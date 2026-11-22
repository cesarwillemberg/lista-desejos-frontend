import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'money.dart';
import 'theme.dart';
import 'widgets/item_card.dart';

class ItemGroup {
  const ItemGroup({required this.id, required this.name, required this.items});

  final String? id;
  final String name;
  final List<WishItem> items;

  String? get remainingLabel => _oneTotal(items.where((item) => !item.purchased));

  String? get boughtLabel => _oneTotal(items.where((item) => item.purchased));

  String? _oneTotal(Iterable<WishItem> source) {
    final priced = source.where((item) => item.price != null).toList();
    if (priced.isEmpty) return null;
    final codes = priced.map((item) => (item.currency ?? '').toUpperCase()).toSet();
    if (codes.length != 1) return 'preços em mais de uma moeda';
    final code = codes.first;
    final sum = priced.fold<double>(0, (total, item) => total + item.price!);
    return formatMoney(sum, code.isEmpty ? null : code);
  }
}

List<ItemGroup> buildGroups(List<WishCategory> categories, List<WishItem> items, {String? filterId, bool keepOrder = false}) {
  final ordered = [...categories]..sort((a, b) => a.position.compareTo(b.position));
  List<WishItem> order(Iterable<WishItem> source) => keepOrder ? source.toList() : sortedWishItems(source);
  final groups = <ItemGroup>[
    for (final category in ordered)
      ItemGroup(
        id: category.id,
        name: category.name,
        items: order(items.where((item) => item.categoryId == category.id)),
      ),
    ItemGroup(id: null, name: 'Sem categoria', items: order(items.where((item) => item.categoryId == null))),
  ];
  if (filterId == null) {
    return groups.where((group) => group.id != null || group.items.isNotEmpty).toList();
  }
  if (filterId.isEmpty) return groups.where((group) => group.id == null).toList();
  return groups.where((group) => group.id == filterId).toList();
}

class GroupedItems extends StatefulWidget {
  const GroupedItems({
    super.key,
    required this.categories,
    required this.items,
    required this.wide,
    required this.cardBuilder,
    this.onRefresh,
    this.onAddInCategory,
    this.embedded = false,
    this.hidePurchased = false,
    this.onHidePurchased,
    this.keepOrder = false,
    this.onReorder,
  });

  final List<WishCategory> categories;
  final List<WishItem> items;
  final bool wide;
  final Widget Function(WishItem item, bool fillHeight) cardBuilder;
  final Future<void> Function()? onRefresh;
  final void Function(String? categoryId)? onAddInCategory;
  final bool embedded;
  final bool hidePurchased;
  final ValueChanged<bool>? onHidePurchased;
  final bool keepOrder;
  final void Function(String? categoryId, int oldIndex, int newIndex)? onReorder;

  @override
  State<GroupedItems> createState() => _GroupedItemsState();
}

class _GroupedItemsState extends State<GroupedItems> {
  String? _filter;
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.hidePurchased ? widget.items.where((item) => !item.purchased).toList() : widget.items;
    final groups = buildGroups(widget.categories, visible, filterId: _filter, keepOrder: widget.keepOrder);
    final chips = SizedBox(
      height: WishlySize.chipRow,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (widget.onHidePurchased != null)
            Padding(
              padding: const EdgeInsets.only(right: WishlySpace.s2),
              child: FilterChip(
                label: const Text('Ocultar comprados'),
                selected: widget.hidePurchased,
                onSelected: widget.onHidePurchased,
                selectedColor: context.wishlyChip,
                checkmarkColor: context.wishlyInk,
                labelStyle: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w600),
              ),
            ),
          _chip('Todas', _filter == null, () => setState(() => _filter = null)),
          for (final category in widget.categories) _chip(category.name, _filter == category.id, () => setState(() => _filter = category.id)),
          _chip('Sem categoria', _filter == '', () => setState(() => _filter = '')),
        ],
      ),
    );
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips,
          const SizedBox(height: WishlySpace.s2),
          for (final group in groups) ...[
            _header(group),
            if (!_collapsed.contains(group.id ?? '')) ...[
              if (group.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: WishlySpace.s4),
                  child: Text('Nenhum item nesta categoria', style: TextStyle(color: QueroColors.muted)),
                )
              else
                _groupItems(group, wide: false),
              const SizedBox(height: WishlySpace.s2),
            ],
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: WishlySpace.s2),
        Expanded(
          child: RefreshIndicator(
            color: QueroColors.ink,
            onRefresh: widget.onRefresh ?? () async {},
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final group in groups) ...[
                _header(group),
                if (!_collapsed.contains(group.id ?? '')) ...[
                  if (group.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: WishlySpace.s4),
                      child: Text('Nenhum item nesta categoria', style: TextStyle(color: QueroColors.muted)),
                    )
                  else
                    _groupItems(group, wide: widget.wide),
                  const SizedBox(height: WishlySpace.s2),
                ],
              ],
            ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: WishlySpace.s2),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: context.wishlyChip,
        checkmarkColor: context.wishlyInk,
        labelStyle: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _groupItems(ItemGroup group, {required bool wide}) {
    if (widget.onReorder == null || group.items.length < 2) {
      if (wide) return ItemWrap(count: group.items.length, itemBuilder: (index) => widget.cardBuilder(group.items[index], false));
      return Column(
        children: [for (final item in group.items) Padding(padding: const EdgeInsets.only(bottom: WishlySpace.s4), child: widget.cardBuilder(item, false))],
      );
    }
    return ReorderableItemList(
      items: group.items,
      wide: wide,
      onReorder: (oldIndex, newIndex) => widget.onReorder!(group.id, oldIndex, newIndex),
      cardBuilder: (item) => widget.cardBuilder(item, false),
    );
  }

  Widget _header(ItemGroup group) {
    final key = group.id ?? '';
    final closed = _collapsed.contains(key);
    final remaining = group.remainingLabel;
    final bought = group.boughtLabel;
    final addLabel = 'Adicionar item em ${group.name}';
    return Padding(
      padding: const EdgeInsets.only(top: WishlySpace.s2, bottom: WishlySpace.s3),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() {
                if (closed) {
                  _collapsed.remove(key);
                } else {
                  _collapsed.add(key);
                }
              }),
              child: Row(
                children: [
                  Icon(closed ? Icons.expand_more : Icons.expand_less, color: QueroColors.ink, size: WishlyIcon.md),
                  const SizedBox(width: WishlySpace.s1),
                  Expanded(child: Text(group.name, style: fraunces(WishlyText.xl2))),
                  Text(
                    '${group.items.length} ${group.items.length == 1 ? 'item' : 'itens'}',
                    style: const TextStyle(color: QueroColors.muted, fontWeight: FontWeight.w600),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(width: WishlySpace.s3),
                    Text(remaining, style: fraunces(WishlyText.lg, color: context.wishlyForest)),
                  ],
                  if (bought != null) ...[
                    const SizedBox(width: WishlySpace.s2),
                    Text(bought, style: fraunces(WishlyText.base, color: context.wishlyMuted).copyWith(decoration: TextDecoration.lineThrough)),
                  ],
                ],
              ),
            ),
          ),
          if (widget.onAddInCategory != null)
            IconButton(
              tooltip: addLabel,
              onPressed: () => widget.onAddInCategory!(group.id),
              icon: const Icon(Icons.add, size: WishlyIcon.md),
            ),
        ],
      ),
    );
  }
}

class ReorderableItemList extends StatelessWidget {
  const ReorderableItemList({super.key, required this.items, required this.wide, required this.cardBuilder, required this.onReorder});

  final List<WishItem> items;
  final bool wide;
  final Widget Function(WishItem item) cardBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        itemCount: items.length,
        onReorderItem: onReorder,
        itemBuilder: (context, index) {
          return Padding(
            key: ValueKey(items[index].id),
            padding: const EdgeInsets.only(bottom: WishlySpace.s4),
            child: cardBuilder(items[index]),
          );
        },
      );
    }
    return ItemWrap(
      count: items.length,
      itemBuilder: (index) {
        final item = items[index];
        return DragTarget<int>(
          onAcceptWithDetails: (details) {
            final from = details.data;
            if (from == index) return;
            onReorder(from, index);
          },
          builder: (context, candidate, rejected) {
            return LongPressDraggable<int>(
              data: index,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: SizedBox(width: WishlyCard.maxWidth, child: Material(elevation: WishlySpace.s2, child: cardBuilder(item))),
              childWhenDragging: Opacity(opacity: WishlyOpacity.placeholder, child: cardBuilder(item)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.drag_indicator, size: WishlyIcon.md, semanticLabel: 'Segure e arraste para reordenar'),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(WishlyCard.radius),
                      border: candidate.isEmpty ? null : Border.all(color: QueroColors.accent, width: WishlySize.stroke),
                    ),
                    child: cardBuilder(item),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
