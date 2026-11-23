import 'package:flutter/gestures.dart';
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
    this.reorderHint,
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
  final String? reorderHint;

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
                Padding(
                  padding: const EdgeInsets.only(bottom: WishlySpace.s4),
                  child: Text('Nenhum item nesta categoria', style: TextStyle(color: context.wishlyMuted)),
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
            color: context.wishlyInk,
            onRefresh: widget.onRefresh ?? () async {},
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final group in groups) ...[
                _header(group),
                if (!_collapsed.contains(group.id ?? '')) ...[
                  if (group.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: WishlySpace.s4),
                      child: Text('Nenhum item nesta categoria', style: TextStyle(color: context.wishlyMuted)),
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
    final canDrag = widget.onReorder != null && group.items.length >= 2;
    if (!canDrag && widget.reorderHint == null) {
      if (wide) return ItemWrap(count: group.items.length, itemBuilder: (index) => widget.cardBuilder(group.items[index], true));
      return Column(
        children: [for (final item in group.items) Padding(padding: const EdgeInsets.only(bottom: WishlySpace.s4), child: widget.cardBuilder(item, false))],
      );
    }
    return ReorderableItemList(
      items: group.items,
      enabled: canDrag,
      hint: widget.reorderHint,
      onReorder: (oldIndex, newIndex) => widget.onReorder?.call(group.id, oldIndex, newIndex),
      cardBuilder: (item) => widget.cardBuilder(item, true),
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
                  Icon(closed ? Icons.expand_more : Icons.expand_less, color: context.wishlyInk, size: WishlyIcon.md),
                  const SizedBox(width: WishlySpace.s1),
                  Expanded(child: Text(group.name, style: fraunces(WishlyText.xl2))),
                  Text(
                    '${group.items.length} ${group.items.length == 1 ? 'item' : 'itens'}',
                    style: TextStyle(color: context.wishlyMuted, fontWeight: FontWeight.w600),
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

class ReorderableItemList extends StatefulWidget {
  const ReorderableItemList({super.key, required this.items, required this.cardBuilder, required this.onReorder, this.enabled = true, this.hint});

  final List<WishItem> items;
  final bool enabled;
  final String? hint;
  final Widget Function(WishItem item) cardBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<ReorderableItemList> createState() => _ReorderableItemListState();
}

class _ReorderableItemListState extends State<ReorderableItemList> {
  final List<GlobalKey> _keys = [];
  OverlayEntry? _entry;
  MultiDragGestureRecognizer? _recognizer;
  int? _from;
  int? _over;
  Offset _grab = Offset.zero;
  Offset _topLeft = Offset.zero;
  double _cellWidth = WishlyCard.maxWidth;

  @override
  void dispose() {
    if (_route != null) GestureBinding.instance.pointerRouter.removeGlobalRoute(_route!);
    _entry?.remove();
    _recognizer?.dispose();
    super.dispose();
  }

  void _syncKeys() {
    while (_keys.length < widget.items.length) {
      _keys.add(GlobalKey());
    }
    if (_keys.length > widget.items.length) _keys.removeRange(widget.items.length, _keys.length);
  }

  void _begin(int index, PointerDownEvent event, MultiDragGestureRecognizer recognizer) {
    if (!widget.enabled || _from != null) return;
    final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _recognizer?.dispose();
    _recognizer = recognizer;
    if (recognizer is! ImmediateMultiDragGestureRecognizer) {
      recognizer.onStart = (Offset position) {
        _showFeedback(index, event);
        return _GridDrag(onUpdate: _move, onEnd: _drop, onCancel: _cancel);
      };
      recognizer.addPointer(event);
      return;
    }
    _showFeedback(index, event);
    final pointer = event.pointer;
    void route(PointerEvent routed) {
      if (routed.pointer != pointer) return;
      if (routed is PointerMoveEvent) {
        _move(routed.position);
      } else if (routed is PointerUpEvent) {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(route);
        _route = null;
        _drop();
      } else if (routed is PointerCancelEvent) {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(route);
        _route = null;
        _cancel();
      }
    }
    _route = route;
    GestureBinding.instance.pointerRouter.addGlobalRoute(route);
    recognizer.onStart = (Offset position) => _GridDrag(onUpdate: (_) {}, onEnd: () {}, onCancel: () {});
    recognizer.addPointer(event);
  }

  void Function(PointerEvent event)? _route;

  void _showFeedback(int index, PointerDownEvent event) {
    final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    _cellWidth = box.size.width;
    _grab = event.position - origin;
    _topLeft = origin;
    setState(() {
      _from = index;
      _over = index;
    });
    _entry?.remove();
    _entry = OverlayEntry(builder: (context) {
      return Positioned(
        left: _topLeft.dx,
        top: _topLeft.dy,
        width: _cellWidth,
        child: IgnorePointer(
          child: Material(
            elevation: WishlySpace.s2,
            color: WishlyColor.transparent,
            child: widget.cardBuilder(widget.items[index]),
          ),
        ),
      );
    });
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _move(Offset global) {
    _topLeft = global - _grab;
    _entry?.markNeedsBuild();
    final next = _indexAt(global);
    if (next != _over && mounted) setState(() => _over = next);
  }

  int? _indexAt(Offset global) {
    for (var index = 0; index < widget.items.length; index++) {
      final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return index;
    }
    return _over;
  }

  void _drop() {
    final from = _from;
    final to = _over;
    _clear();
    if (from != null && to != null && from != to) widget.onReorder(from, to);
  }

  void _cancel() => _clear();

  void _clear() {
    _entry?.remove();
    _entry = null;
    final recognizer = _recognizer;
    _recognizer = null;
    _from = null;
    _over = null;
    if (mounted) setState(() {});
    if (recognizer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => recognizer.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncKeys();
    return _ReorderScope(
      begin: _begin,
      child: ItemWrap(
        count: widget.items.length,
        itemBuilder: (index) {
          final item = widget.items[index];
          final dragging = _from == index;
          final target = _over == index && _from != null && _from != index;
          return DecoratedBox(
            key: _keys[index],
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WishlyCard.radius),
              border: target ? Border.all(color: WishlyColor.accent, width: WishlySize.strokeBold) : null,
            ),
            child: Opacity(
              opacity: dragging ? WishlyOpacity.placeholder : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.cardBuilder(item),
                  if (widget.enabled) Positioned.fill(child: _DelayedDragSurface(index: index)),
                  Positioned(
                    top: WishlySpace.s5,
                    right: WishlySpace.s5,
                    child: _DragHandle(
                      index: index,
                      enabled: widget.enabled,
                      hint: widget.hint ?? 'Segure e arraste para reordenar',
                      immediate: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReorderScope extends InheritedWidget {
  const _ReorderScope({required this.begin, required super.child});

  final void Function(int index, PointerDownEvent event, MultiDragGestureRecognizer recognizer) begin;

  static _ReorderScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ReorderScope>();
    assert(scope != null, 'Reorder fora do grid');
    return scope!;
  }

  @override
  bool updateShouldNotify(_ReorderScope oldWidget) => false;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index, required this.enabled, required this.hint, required this.immediate});

  final int index;
  final bool enabled;
  final String hint;
  final bool immediate;

  @override
  Widget build(BuildContext context) {
    final grip = MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.forbidden,
      child: Tooltip(
        message: enabled ? 'Arraste para reordenar' : hint,
        child: Semantics(
          button: true,
          container: true,
          label: enabled ? 'Arraste para reordenar' : hint,
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.wishlyScrim, borderRadius: BorderRadius.circular(WishlyRadius.md)),
            child: const Padding(
              padding: EdgeInsets.all(WishlySpace.s2),
              child: Icon(Icons.drag_indicator, size: WishlyIcon.md, color: WishlyColor.white),
            ),
          ),
        ),
      ),
    );
    if (!enabled) return grip;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryButton) return;
        final settings = MediaQuery.maybeGestureSettingsOf(context);
        final recognizer = (immediate ? ImmediateMultiDragGestureRecognizer(debugOwner: this) : DelayedMultiDragGestureRecognizer(debugOwner: this))
          ..gestureSettings = settings;
        _ReorderScope.of(context).begin(index, event, recognizer);
      },
      child: grip,
    );
  }
}

class _DelayedDragSurface extends StatelessWidget {
  const _DelayedDragSurface({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) return;
        final settings = MediaQuery.maybeGestureSettingsOf(context);
        final recognizer = DelayedMultiDragGestureRecognizer(debugOwner: this, delay: const Duration(milliseconds: 350))..gestureSettings = settings;
        _ReorderScope.of(context).begin(index, event, recognizer);
      },
    );
  }
}

class _GridDrag extends Drag {
  _GridDrag({required this.onUpdate, required this.onEnd, required this.onCancel});

  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.globalPosition);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onCancel();
}
