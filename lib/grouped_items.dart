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

List<ItemGroup> buildGroups(List<WishCategory> categories, List<WishItem> items, {String? filterId}) {
  final ordered = [...categories]..sort((a, b) => a.position.compareTo(b.position));
  final groups = <ItemGroup>[
    for (final category in ordered)
      ItemGroup(
        id: category.id,
        name: category.name,
        items: sortedWishItems(items.where((item) => item.categoryId == category.id)),
      ),
    ItemGroup(id: null, name: 'Sem categoria', items: sortedWishItems(items.where((item) => item.categoryId == null))),
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
    this.embedded = false,
    this.hidePurchased = false,
    this.onHidePurchased,
  });

  final List<WishCategory> categories;
  final List<WishItem> items;
  final bool wide;
  final Widget Function(WishItem item, bool fillHeight) cardBuilder;
  final Future<void> Function()? onRefresh;
  final bool embedded;
  final bool hidePurchased;
  final ValueChanged<bool>? onHidePurchased;

  @override
  State<GroupedItems> createState() => _GroupedItemsState();
}

class _GroupedItemsState extends State<GroupedItems> {
  String? _filter;
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.hidePurchased ? widget.items.where((item) => !item.purchased).toList() : widget.items;
    final groups = buildGroups(widget.categories, visible, filterId: _filter);
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
                selectedColor: WishlyTokens.chip,
                checkmarkColor: QueroColors.ink,
                labelStyle: const TextStyle(color: QueroColors.ink, fontWeight: FontWeight.w600),
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
                for (final item in group.items) Padding(padding: const EdgeInsets.only(bottom: WishlySpace.s4), child: widget.cardBuilder(item, false)),
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
                  else if (widget.wide)
                    ItemWrap(count: group.items.length, itemBuilder: (index) => widget.cardBuilder(group.items[index], false))
                  else
                    for (final item in group.items)
                      Padding(padding: const EdgeInsets.only(bottom: WishlySpace.s4), child: widget.cardBuilder(item, false)),
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
        selectedColor: WishlyTokens.chip,
        checkmarkColor: QueroColors.ink,
        labelStyle: const TextStyle(color: QueroColors.ink, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _header(ItemGroup group) {
    final key = group.id ?? '';
    final closed = _collapsed.contains(key);
    final remaining = group.remainingLabel;
    final bought = group.boughtLabel;
    return InkWell(
      onTap: () => setState(() {
        if (closed) {
          _collapsed.remove(key);
        } else {
          _collapsed.add(key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.only(top: WishlySpace.s2, bottom: WishlySpace.s3),
        child: Row(
          children: [
            Icon(closed ? Icons.expand_more : Icons.expand_less, color: QueroColors.ink),
            const SizedBox(width: WishlySpace.s1),
            Expanded(child: Text(group.name, style: fraunces(WishlyText.xl2))),
            Text(
              '${group.items.length} ${group.items.length == 1 ? 'item' : 'itens'}',
              style: const TextStyle(color: QueroColors.muted, fontWeight: FontWeight.w600),
            ),
            if (remaining != null) ...[
              const SizedBox(width: WishlySpace.s3),
              Text(remaining, style: fraunces(WishlyText.lg, color: QueroColors.forest)),
            ],
            if (bought != null) ...[
              const SizedBox(width: WishlySpace.s2),
              Text(bought, style: fraunces(WishlyText.base, color: QueroColors.muted).copyWith(decoration: TextDecoration.lineThrough)),
            ],
          ],
        ),
      ),
    );
  }
}
