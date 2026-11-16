import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/add_form.dart';
import 'widgets/edit_dialog.dart';
import 'widgets/item_card.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  WishList? _list;
  List<WishItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  WishlistSnapshot get _snapshot => WishlistSnapshot(items: _items, unpricedCount: _items.where((item) => item.price == null).length, title: _list?.name);

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final snapshot = await SessionScope.of(context).api.listItems(widget.listId);
      if (!mounted) return;
      final lists = await SessionScope.of(context).api.lists();
      if (!mounted) return;
      setState(() {
        _items = snapshot.items;
        WishList? match;
        for (final candidate in lists) {
          if (candidate.id == widget.listId) match = candidate;
        }
        _list = match;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _insert(WishItem item) {
    setState(() => _items = [item, ..._items.where((current) => current.id != item.id)]);
    final message = item.status == 'ok' ? '${item.name} entrou na lista.' : (item.message ?? 'Item salvo.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _replace(WishItem item) {
    setState(() => _items = [for (final current in _items) current.id == item.id ? item : current]);
  }

  Future<void> _refresh(WishItem item) async {
    setState(() => _busyId = item.id);
    try {
      final updated = await SessionScope.of(context).api.refreshItem(item.id);
      if (!mounted) return;
      _replace(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(WishItem item) async {
    final updated = await showEditDialog(context, api: SessionScope.of(context).api, item: item);
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QueroColors.cream,
        title: Text('Excluir este item?', style: fraunces(24)),
        content: Text('“${item.name}” sai da lista.'),
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
    if (yes != true || !mounted) return;
    try {
      await SessionScope.of(context).api.deleteItem(item.id);
      if (!mounted) return;
      setState(() => _items = _items.where((current) => current.id != item.id).toList());
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _clearReservation(WishItem item) async {
    try {
      await SessionScope.of(context).api.clearOwnedReservation(item.id);
      if (!mounted) return;
      _replace(WishItem(
        id: item.id,
        name: item.name,
        url: item.url,
        status: item.status,
        createdAt: item.createdAt,
        updatedAt: DateTime.now(),
        imageUrl: item.imageUrl,
        price: item.price,
        currency: item.currency,
        store: item.store,
        message: item.message,
        listId: item.listId,
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _share() async {
    final api = SessionScope.of(context).api;
    var list = _list;
    if (list == null) return;
    if (list.shareToken == null) {
      try {
        list = await api.shareList(list.id);
        if (!mounted) return;
        setState(() => _list = list);
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    if (!mounted || list.shareToken == null) return;
    final link = api.shareLink(list.shareToken!);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QueroColors.cream,
        title: Text('Compartilhar', style: fraunces(26)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Quem abrir o link vê a lista e pode marcar “Já comprei”, sem entrar na sua conta.'),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () async {
              final updated = await api.regenerateShare(list!.id);
              if (!context.mounted) return;
              setState(() => _list = updated);
              Navigator.pop(context);
            },
            child: const Text('Gerar novo'),
          ),
          TextButton(
            onPressed: () async {
              final updated = await api.revokeShare(list!.id);
              if (!context.mounted) return;
              setState(() => _list = updated);
              Navigator.pop(context);
            },
            child: const Text('Revogar', style: TextStyle(color: QueroColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    final name = _list?.name ?? _snapshot.title ?? 'Lista';
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final board = _Board(
          title: name,
          items: _items,
          loading: _loading,
          error: _error,
          busyId: _busyId,
          wide: wide,
          snapshot: _snapshot,
          api: api,
          onBack: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
          onShare: _share,
          onReload: _load,
          onRefresh: _refresh,
          onEdit: _edit,
          onOpen: _open,
          onDelete: _delete,
          onUnreserve: _clearReservation,
        );
        if (!wide) {
          return Scaffold(
            backgroundColor: QueroColors.paper,
            body: board,
            bottomNavigationBar: _list == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _AddButton(onPressed: () => _openAdd(api)),
                    ),
                  ),
          );
        }
        return Scaffold(
          backgroundColor: QueroColors.paper,
          body: Row(
            children: [
              SizedBox(
                width: 380,
                child: ColoredBox(
                  color: QueroColors.ink,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false), child: const Text('← Suas listas', style: TextStyle(color: QueroColors.cream))),
                          Text(name, style: fraunces(40, color: QueroColors.cream)),
                          const SizedBox(height: 18),
                          if (_list != null) Expanded(child: SingleChildScrollView(child: AddPanel(api: api, listId: _list!.id, onDark: true, onCreated: _insert))),
                          _TotalBlock(snapshot: _snapshot, onDark: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: board),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAdd(QueroApi api) async {
    final list = _list;
    if (list == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: QueroColors.paper,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: AddPanel(
          api: api,
          listId: list.id,
          onCreated: (item) {
            Navigator.pop(context);
            _insert(item);
          },
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: const Text('Adicionar item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.title,
    required this.items,
    required this.loading,
    required this.error,
    required this.busyId,
    required this.wide,
    required this.snapshot,
    required this.api,
    required this.onBack,
    required this.onShare,
    required this.onReload,
    required this.onRefresh,
    required this.onEdit,
    required this.onOpen,
    required this.onDelete,
    required this.onUnreserve,
  });

  final String title;
  final List<WishItem> items;
  final bool loading;
  final String? error;
  final String? busyId;
  final bool wide;
  final WishlistSnapshot snapshot;
  final QueroApi api;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onReload;
  final void Function(WishItem) onRefresh;
  final void Function(WishItem) onEdit;
  final void Function(WishItem) onOpen;
  final void Function(WishItem) onDelete;
  final void Function(WishItem) onUnreserve;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, wide ? 20 : 8, wide ? 28 : 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (!wide) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                Expanded(child: Text(wide ? 'Itens' : title, style: fraunces(wide ? 32 : 26))),
                IconButton(onPressed: onShare, tooltip: 'Compartilhar', icon: const Icon(Icons.ios_share)),
                IconButton(onPressed: onReload, tooltip: 'Recarregar', icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          if (!wide) _TotalBlock(snapshot: snapshot, onDark: false),
          const SizedBox(height: 8),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (loading) return const Center(child: CircularProgressIndicator(color: QueroColors.ink));
    if (error != null && items.isEmpty) return Center(child: Text(error!, textAlign: TextAlign.center));
    if (items.isEmpty) return Center(child: Text('Nada por aqui ainda', style: fraunces(28), textAlign: TextAlign.center));
    if (wide) {
      return GridView.builder(
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 380, mainAxisExtent: 520, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemBuilder: (context, index) => _card(items[index], fillHeight: true),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _card(items[index], fillHeight: false),
    );
  }

  Widget _card(WishItem item, {required bool fillHeight}) {
    return ItemCard(
      item: item,
      proxyUrl: api.imageProxy(item),
      imageHeaders: api.authHeaders,
      busy: busyId == item.id,
      fillHeight: fillHeight,
      onRefresh: () => onRefresh(item),
      onEdit: () => onEdit(item),
      onOpen: () => onOpen(item),
      onDelete: () => onDelete(item),
      onUnreserve: item.reserved ? () => onUnreserve(item) : null,
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
            Text(formatMoney(total.amount, total.currency.isEmpty ? null : total.currency), style: fraunces(onDark ? 32 : 26, color: value)),
      ],
    );
  }
}
