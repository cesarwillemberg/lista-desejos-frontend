import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'money.dart';
import 'theme.dart';

class ItemGroup {
  const ItemGroup({required this.id, required this.name, required this.items});

  final String? id;
  final String name;
  final List<WishItem> items;

  String? get subtotal {
    final priced = items.where((item) => item.price != null).toList();
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
        items: items.where((item) => item.categoryId == category.id).toList(),
      ),
    ItemGroup(id: null, name: 'Sem categoria', items: items.where((item) => item.categoryId == null).toList()),
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
  });

  final List<WishCategory> categories;
  final List<WishItem> items;
  final bool wide;
  final Widget Function(WishItem item, bool fillHeight) cardBuilder;

  @override
  State<GroupedItems> createState() => _GroupedItemsState();
}

class _GroupedItemsState extends State<GroupedItems> {
  String? _filter;
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final groups = buildGroups(widget.categories, widget.items, filterId: _filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('Todas', _filter == null, () => setState(() => _filter = null)),
              for (final category in widget.categories)
                _chip(category.name, _filter == category.id, () => setState(() => _filter = category.id)),
              _chip('Sem categoria', _filter == '', () => setState(() => _filter = '')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final group in groups) ...[
                _header(group),
                if (!_collapsed.contains(group.id ?? '')) ...[
                  if (group.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('Nenhum item nesta categoria', style: TextStyle(color: QueroColors.muted)),
                    )
                  else if (widget.wide)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.items.length,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisExtent: 460,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) => widget.cardBuilder(group.items[index], true),
                    )
                  else
                    for (final item in group.items)
                      Padding(padding: const EdgeInsets.only(bottom: 14), child: widget.cardBuilder(item, false)),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFF3D2C4),
        checkmarkColor: QueroColors.ink,
        labelStyle: const TextStyle(color: QueroColors.ink, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _header(ItemGroup group) {
    final key = group.id ?? '';
    final closed = _collapsed.contains(key);
    final subtotal = group.subtotal;
    return InkWell(
      onTap: () => setState(() {
        if (closed) {
          _collapsed.remove(key);
        } else {
          _collapsed.add(key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(
          children: [
            Icon(closed ? Icons.expand_more : Icons.expand_less, color: QueroColors.ink),
            const SizedBox(width: 4),
            Expanded(child: Text(group.name, style: fraunces(24))),
            Text(
              '${group.items.length} ${group.items.length == 1 ? 'item' : 'itens'}',
              style: const TextStyle(color: QueroColors.muted, fontWeight: FontWeight.w600),
            ),
            if (subtotal != null) ...[
              const SizedBox(width: 12),
              Text(subtotal, style: fraunces(18, color: QueroColors.forest)),
            ],
          ],
        ),
      ),
    );
  }
}
