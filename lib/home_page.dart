import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'theme.dart';
import 'widgets/add_form.dart';
import 'widgets/edit_dialog.dart';
import 'widgets/item_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final QueroApi api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WishItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  WishlistSnapshot get _snapshot => WishlistSnapshot(items: _items, unpricedCount: _items.where((item) => item.price == null).length);

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final snapshot = await widget.api.listItems();
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _items = snapshot.items;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _insert(WishItem item) {
    setState(() {
      _items = [item, ..._items.where((current) => current.id != item.id)];
      _error = null;
      _loading = false;
    });
    final message = item.status == 'ok' ? '${item.name} entrou na lista.' : (item.message ?? 'Item salvo. Complete a foto ou o preço se precisar.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _replace(WishItem item) {
    setState(() {
      _items = [for (final current in _items) current.id == item.id ? item : current];
    });
  }

  Future<void> _refresh(WishItem item) async {
    setState(() => _busyId = item.id);
    try {
      final updated = await widget.api.refreshItem(item.id);
      if (!mounted) return;
      _replace(updated);
      final message = updated.message ?? 'Foto e preço atualizados.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(WishItem item) async {
    final updated = await showEditDialog(context, api: widget.api, item: item);
    if (updated != null) _replace(updated);
  }

  Future<void> _open(WishItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
    }
  }

  Future<void> _delete(WishItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QueroColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Excluir este item?', style: fraunces(26)),
        content: Text('“${item.name}” sai da lista. A página da loja não muda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: QueroColors.danger, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = item.id);
    try {
      await widget.api.deleteItem(item.id);
      if (!mounted) return;
      setState(() => _items = _items.where((current) => current.id != item.id).toList());
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: QueroColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 42, height: 4, decoration: BoxDecoration(color: QueroColors.line, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 18),
                AddPanel(
                  api: widget.api,
                  onCreated: (item) {
                    Navigator.of(context).pop();
                    _insert(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Scaffold(
            backgroundColor: QueroColors.paper,
            body: Row(
              children: [
                SizedBox(width: 380, child: _Sidebar(api: widget.api, snapshot: _snapshot, onCreated: _insert)),
                Expanded(child: _Board(state: this, wide: true)),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: QueroColors.paper,
          body: Column(
            children: [
              _MobileBar(onReload: _load),
              Expanded(child: _Board(state: this, wide: false)),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                onPressed: _openAddSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: QueroColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Adicionar item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.api, required this.snapshot, required this.onCreated});

  final QueroApi api;
  final WishlistSnapshot snapshot;
  final ValueChanged<WishItem> onCreated;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QueroColors.ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quero', style: fraunces(48, style: FontStyle.italic, color: QueroColors.cream, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'O que você quer comprar, num lugar só.',
                style: TextStyle(color: Color(0xFFD7CDC2), fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(child: AddPanel(api: api, onDark: true, onCreated: onCreated)),
              ),
              const SizedBox(height: 18),
              _TotalBlock(snapshot: snapshot, onDark: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBar extends StatelessWidget {
  const _MobileBar({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QueroColors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quero', style: fraunces(32, style: FontStyle.italic, color: QueroColors.cream)),
                    const SizedBox(height: 2),
                    const Text('Lista de desejos', style: TextStyle(color: Color(0xFFD7CDC2), fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onReload,
                color: QueroColors.cream,
                tooltip: 'Recarregar',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.state, required this.wide});

  final _HomePageState state;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = state._items;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, wide ? 28 : 16, wide ? 28 : 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Sua lista', style: fraunces(wide ? 36 : 28)),
              const Spacer(),
              Text(
                items.length == 1 ? '1 item' : '${items.length} itens',
                style: const TextStyle(color: QueroColors.muted, fontWeight: FontWeight.w600),
              ),
              if (wide)
                IconButton(onPressed: state._load, tooltip: 'Recarregar', icon: const Icon(Icons.refresh), color: QueroColors.ink),
            ],
          ),
          const SizedBox(height: 6),
          if (!wide) _TotalBlock(snapshot: state._snapshot, onDark: false),
          const SizedBox(height: 12),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (state._loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: QueroColors.ink),
            SizedBox(height: 14),
            Text('Carregando sua lista…', style: TextStyle(color: QueroColors.muted)),
          ],
        ),
      );
    }
    if (state._error != null && state._items.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state._error!, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: state._load, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }
    if (state._items.isEmpty) {
      return const _Empty();
    }
    if (wide) {
      return GridView.builder(
        itemCount: state._items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 520,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) => _card(state._items[index], fillHeight: true),
      );
    }
    return ListView.separated(
      itemCount: state._items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _card(state._items[index], fillHeight: false),
    );
  }

  Widget _card(WishItem item, {required bool fillHeight}) {
    return ItemCard(
      item: item,
      proxyUrl: state.widget.api.imageProxy(item),
      busy: state._busyId == item.id,
      fillHeight: fillHeight,
      onRefresh: () => state._refresh(item),
      onEdit: () => state._edit(item),
      onOpen: () => state._open(item),
      onDelete: () => state._delete(item),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nada por aqui ainda', style: fraunces(32), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Cole o link de um produto e dê um nome. Buscamos a foto e o preço para você. Se a loja bloquear a leitura, o item entra mesmo assim.',
              textAlign: TextAlign.center,
              style: TextStyle(color: QueroColors.muted, fontSize: 15, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.snapshot, required this.onDark});

  final WishlistSnapshot snapshot;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final label = onDark ? const Color(0xFFB7ADA3) : QueroColors.muted;
    final value = onDark ? QueroColors.cream : QueroColors.forest;
    final totals = snapshot.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOTAL DA LISTA', style: TextStyle(color: label, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (totals.isEmpty)
          Text('Sem preços para somar', style: TextStyle(color: value, fontSize: 18, fontWeight: FontWeight.w600))
        else
          for (final total in totals)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                formatMoney(total.amount, total.currency.isEmpty ? null : total.currency),
                style: fraunces(onDark ? 34 : 26, color: value),
              ),
            ),
        if (snapshot.unpricedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              snapshot.unpricedCount == 1
                  ? '1 item sem preço, fora do total'
                  : '${snapshot.unpricedCount} itens sem preço, fora do total',
              style: TextStyle(color: label, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
