import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'money.dart';
import 'theme.dart';
import 'widgets/member_avatars.dart';

const _widthKey = 'quero_sidebar_width';
const _collapsedKey = 'quero_sidebar_collapsed';
const _minWidth = 260.0;
const _maxWidth = 480.0;
const _railWidth = 76.0;

class ListSidebar extends StatefulWidget {
  const ListSidebar({
    super.key,
    required this.lists,
    required this.currentId,
    required this.title,
    required this.snapshot,
    required this.onBack,
    required this.onSelect,
    required this.onCreate,
    this.onMembers,
    this.resizable = true,
  });

  final List<WishList> lists;
  final String? currentId;
  final String title;
  final WishlistSnapshot snapshot;
  final VoidCallback onBack;
  final ValueChanged<WishList> onSelect;
  final VoidCallback onCreate;
  final VoidCallback? onMembers;
  final bool resizable;

  @override
  State<ListSidebar> createState() => _ListSidebarState();
}

class _ListSidebarState extends State<ListSidebar> {
  double _width = 320;
  bool _collapsed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _width = (prefs.getDouble(_widthKey) ?? 320).clamp(_minWidth, _maxWidth);
      _collapsed = prefs.getBool(_collapsedKey) ?? false;
      _ready = true;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widthKey, _width);
    await prefs.setBool(_collapsedKey, _collapsed);
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.resizable) {
      return SizedBox.expand(child: _panel(collapsed: false));
    }
    final width = !_ready ? 320.0 : (_collapsed ? _railWidth : _width);
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(child: _panel(collapsed: _ready && _collapsed)),
          if (_ready && !_collapsed)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() => _width = (_width + details.delta.dx).clamp(_minWidth, _maxWidth));
                  },
                  onHorizontalDragEnd: (_) => _persist(),
                  child: const SizedBox(width: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel({required bool collapsed}) {
    return ColoredBox(
      color: QueroColors.ink,
      child: SafeArea(
        child: collapsed ? _rail() : _expanded(),
      ),
    );
  }

  Widget _rail() {
    return Column(
      children: [
        IconButton(onPressed: _toggle, tooltip: 'Expandir', color: QueroColors.cream, icon: const Icon(Icons.keyboard_double_arrow_right)),
        IconButton(onPressed: widget.onBack, tooltip: 'Suas listas', color: QueroColors.cream, icon: const Icon(Icons.arrow_back)),
        const Divider(color: Color(0xFF4A3F37)),
        Expanded(
          child: ListView(
            children: [
              for (final list in widget.lists)
                Tooltip(
                  message: list.name,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      onTap: () => widget.onSelect(list),
                      child: CircleAvatar(
                        backgroundColor: list.id == widget.currentId ? QueroColors.accent : const Color(0xFF4A3F37),
                        child: Text(
                          list.name.isEmpty ? '?' : list.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(onPressed: widget.onCreate, tooltip: 'Nova lista', color: QueroColors.cream, icon: const Icon(Icons.add)),
      ],
    );
  }

  Widget _expanded() {
    final total = widget.snapshot.totals.isEmpty
        ? 'Sem preços para somar'
        : formatMoney(widget.snapshot.totals.first.amount, widget.snapshot.totals.first.currency.isEmpty ? null : widget.snapshot.totals.first.currency);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onBack,
                  style: TextButton.styleFrom(foregroundColor: QueroColors.cream, alignment: Alignment.centerLeft),
                  child: const Text('← Suas listas'),
                ),
              ),
              if (widget.resizable)
                IconButton(onPressed: _toggle, tooltip: 'Recolher', color: QueroColors.cream, icon: const Icon(Icons.keyboard_double_arrow_left)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: fraunces(32, color: QueroColors.cream)),
          ),
          if (widget.onMembers != null)
            TextButton.icon(
              onPressed: widget.onMembers,
              icon: const Icon(Icons.group_outlined, color: QueroColors.cream, size: 18),
              label: const Text('Membros', style: TextStyle(color: QueroColors.cream)),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(child: Text('LISTAS', style: TextStyle(color: Color(0xFFB7ADA3), fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w700))),
                TextButton(onPressed: widget.onCreate, child: const Text('Nova lista', style: TextStyle(color: QueroColors.accent))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final list in widget.lists)
                  ListTile(
                    selected: list.id == widget.currentId,
                    selectedTileColor: const Color(0xFF3A2F28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: list.id == widget.currentId ? Colors.white : QueroColors.cream, fontWeight: FontWeight.w700)),
                    subtitle: list.collaborative
                        ? Row(
                            children: [
                              MemberAvatars(members: list.members, onDark: true),
                              const SizedBox(width: 8),
                              const SharedBadge(onDark: true),
                            ],
                          )
                        : null,
                    isThreeLine: list.collaborative,
                    trailing: Text('${list.itemCount}', style: const TextStyle(color: Color(0xFFD7CDC2))),
                    onTap: () => widget.onSelect(list),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('TOTAL DA LISTA', style: TextStyle(color: Color(0xFFB7ADA3), fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(total, style: fraunces(28, color: QueroColors.cream)),
          ),
        ],
      ),
    );
  }
}
