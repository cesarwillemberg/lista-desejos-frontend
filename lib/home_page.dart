import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'grouped_items.dart';
import 'list_sidebar.dart';
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
  List<WishList> _allLists = [];
  List<WishItem> _items = [];
  List<WishCategory> _categories = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      final api = SessionScope.of(context).api;
      final snapshot = await api.listItems(widget.listId);
      if (!mounted) return;
      final lists = await api.lists();
      if (!mounted) return;
      WishList? match;
      for (final candidate in lists) {
        if (candidate.id == widget.listId) match = candidate;
      }
      setState(() {
        _allLists = lists;
        _items = snapshot.items;
        _categories = snapshot.categories;
        _list = match;
        _loading = false;
        _error = match == null ? 'Lista não encontrada.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : 'Não foi possível carregar os itens. Tente de novo.';
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
    final updated = await showEditDialog(
      context,
      api: SessionScope.of(context).api,
      item: item,
      categories: _categories,
      onCreateCategory: (name) async {
        final created = await SessionScope.of(context).api.createCategory(widget.listId, name);
        if (mounted) setState(() => _categories = [..._categories, created]);
        return created;
      },
    );
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

  Future<void> _shareOrCopy(String link) async {
    try {
      final result = await SharePlus.instance.share(ShareParams(text: link, subject: 'Lista no Quero'));
      if (result.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: link));
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
    }
  }

  Future<void> _share() async {
    final api = SessionScope.of(context).api;
    var list = _list;
    if (list == null) return;
    if (list.shareToken == null && list.shortCode == null) {
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
    if (!mounted || (list.shortUrl == null && list.shareToken == null && list.shortCode == null)) return;
    final link = list.shortUrl ?? api.shareLink(list.shortCode ?? list.shareToken!);
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
              await _shareOrCopy(link);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enviar'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado.')));
                Navigator.pop(context);
              }
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
          categories: _categories,
          api: api,
          onAdd: _list == null ? null : () => _openAdd(api, wide: wide),
          onCategories: _manageCategories,
          onMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
          onBack: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
          onShare: _share,
          onReload: _load,
          onRefresh: _refresh,
          onEdit: _edit,
          onOpen: _open,
          onDelete: _delete,
          onUnreserve: _clearReservation,
        );
        final sidebar = ListSidebar(
          lists: _allLists,
          currentId: widget.listId,
          title: name,
          snapshot: _snapshot,
          resizable: wide,
          onBack: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
          onSelect: (list) {
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
            if (list.id == widget.listId) return;
            Navigator.of(context).pushReplacementNamed('/list/${list.id}');
          },
          onCreate: _createList,
        );
        if (!wide) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: QueroColors.paper,
            drawer: Drawer(backgroundColor: QueroColors.ink, child: sidebar),
            floatingActionButton: _list == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _openAdd(api, wide: false),
                    backgroundColor: QueroColors.accent,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                  ),
            body: board,
          );
        }
        return Scaffold(
          backgroundColor: QueroColors.paper,
          body: Row(children: [sidebar, Expanded(child: board)]),
        );
      },
    );
  }

  Future<void> _manageCategories() async {
    final list = _list;
    if (list == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CategoryManager(
        api: SessionScope.of(context).api,
        listId: list.id,
        categories: _categories,
        onChanged: (categories, items) {
          setState(() {
            _categories = categories;
            if (items != null) _items = items;
          });
        },
      ),
    );
  }

  Future<void> _createList() async {
    final api = SessionScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = await _askListName(context);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final created = await api.createList(name);
      if (!mounted) return;
      navigator.pushReplacementNamed('/list/${created.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openAdd(QueroApi api, {required bool wide}) async {
    final list = _list;
    if (list == null) return;
    final panel = AddPanel(
      api: api,
      listId: list.id,
      categories: _categories,
      onCategoryCreated: (category) => setState(() => _categories = [..._categories, category]),
      onCreated: (item) {
        Navigator.pop(context);
        _insert(item);
      },
    );
    if (!wide) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: QueroColors.paper,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: panel,
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: QueroColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 24), child: panel),
        ),
      ),
    );
  }
}

Future<String?> _askListName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: QueroColors.cream,
      title: Text('Nova lista', style: fraunces(24)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Nome da lista')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
          child: const Text('Criar'),
        ),
      ],
    ),
  );
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
    required this.categories,
    required this.api,
    this.onAdd,
    required this.onCategories,
    this.onMenu,
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
  final List<WishCategory> categories;
  final QueroApi api;
  final VoidCallback? onAdd;
  final VoidCallback onCategories;
  final VoidCallback? onMenu;
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
                if (onMenu != null) IconButton(onPressed: onMenu, tooltip: 'Listas', icon: const Icon(Icons.menu)),
                if (!wide && onMenu == null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                Expanded(child: Text(wide ? 'Itens' : title, style: fraunces(wide ? 32 : 26))),
                if (wide && onAdd != null)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                    style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
                  ),
                IconButton(onPressed: onCategories, tooltip: 'Categorias', icon: const Icon(Icons.category_outlined)),
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
    if (error != null && items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(error!, textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onReload, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    if (items.isEmpty && categories.isEmpty) {
      return Center(child: Text('Nada por aqui ainda', style: fraunces(28), textAlign: TextAlign.center));
    }
    if (categories.isEmpty) {
      if (wide) {
        return GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 520,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) => _card(items[index], fillHeight: true),
        );
      }
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _card(items[index], fillHeight: false),
      );
    }
    return GroupedItems(categories: categories, items: items, wide: wide, cardBuilder: (item, fill) => _card(item, fillHeight: fill));
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

class _CategoryManager extends StatefulWidget {
  const _CategoryManager({required this.api, required this.listId, required this.categories, required this.onChanged});

  final QueroApi api;
  final String listId;
  final List<WishCategory> categories;
  final void Function(List<WishCategory> categories, List<WishItem>? items) onChanged;

  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  late List<WishCategory> _categories;
  final _name = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    try {
      final created = await widget.api.createCategory(widget.listId, name);
      _name.clear();
      setState(() => _categories = [..._categories, created]);
      widget.onChanged(_categories, null);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _rename(WishCategory category) async {
    final name = await _askCategoryName(context);
    if (name == null || name.isEmpty) return;
    try {
      final updated = await widget.api.renameCategory(category.id, name);
      setState(() => _categories = [for (final current in _categories) current.id == category.id ? updated : current]);
      widget.onChanged(_categories, null);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _delete(WishCategory category) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QueroColors.cream,
        title: Text('Excluir “${category.name}”?', style: fraunces(24)),
        content: const Text('Os itens dessa categoria passam para Sem categoria.'),
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
    if (yes != true) return;
    try {
      await widget.api.deleteCategory(category.id);
      final snapshot = await widget.api.listItems(widget.listId);
      setState(() => _categories = snapshot.categories);
      widget.onChanged(snapshot.categories, snapshot.items);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _move(int index, int delta) async {
    final next = index + delta;
    if (next < 0 || next >= _categories.length) return;
    final reordered = [..._categories];
    final item = reordered.removeAt(index);
    reordered.insert(next, item);
    try {
      final saved = await widget.api.reorderCategories(widget.listId, [for (final category in reordered) category.id]);
      setState(() => _categories = saved);
      widget.onChanged(saved, null);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: QueroColors.cream,
      title: Text('Categorias', style: fraunces(26)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_categories.isEmpty) const Text('Nenhuma categoria ainda. A lista continua sem grupos.'),
            for (var i = 0; i < _categories.length; i++)
              Row(
                children: [
                  Expanded(child: Text(_categories[i].name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(onPressed: i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward), tooltip: 'Subir'),
                  IconButton(onPressed: i == _categories.length - 1 ? null : () => _move(i, 1), icon: const Icon(Icons.arrow_downward), tooltip: 'Descer'),
                  TextButton(onPressed: () => _rename(_categories[i]), child: const Text('Renomear')),
                  TextButton(onPressed: () => _delete(_categories[i]), child: const Text('Excluir', style: TextStyle(color: QueroColors.danger))),
                ],
              ),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Nova categoria'), onSubmitted: (_) => _add()),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: QueroColors.danger))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _add, child: const Text('Adicionar')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

Future<String?> _askCategoryName(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: QueroColors.cream,
      title: Text('Renomear', style: fraunces(24)),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
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
