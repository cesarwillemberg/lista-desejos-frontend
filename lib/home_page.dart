import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'grouped_items.dart';
import 'list_sidebar.dart';
import 'members_dialog.dart';
import 'widgets/item_form.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_card.dart';
import 'widgets/skeleton.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> with WidgetsBindingObserver {
  WishList? _list;
  List<WishList> _allLists = [];
  List<WishItem> _items = [];
  List<WishCategory> _categories = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  var _hidePurchased = false;
  var _query = '';
  var _sort = 'manual';
  var _priority = 'todas';
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  var _started = false;
  DateTime? _loadedAt;
  Timer? _poll;
  DateTime? _pollSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) return;
    final last = _loadedAt;
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 60)) return;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadSort();
    _load();
  }

  Future<void> _loadSort() async {
    final saved = (await SharedPreferences.getInstance()).getString('wishly_sort_${widget.listId}');
    if (!mounted || saved == null) return;
    const allowed = {'manual', 'price_asc', 'price_desc', 'date', 'store', 'name', 'priority'};
    if (allowed.contains(saved)) setState(() => _sort = saved);
  }

  Future<void> _setSort(String value) async {
    setState(() => _sort = value);
    await (await SharedPreferences.getInstance()).setString('wishly_sort_${widget.listId}', value);
  }

  WishlistSnapshot get _snapshot => WishlistSnapshot(items: _items, unpricedCount: _items.where((item) => item.price == null).length, title: _list?.name);

  List<WishItem> _arranged(List<WishItem> source) {
    final query = _query.trim().toLowerCase();
    final items = source.where((item) {
      if (_priority != 'todas' && item.priority != _priority) return false;
      if (query.isEmpty) return true;
      final details = '${item.colorName ?? ''} ${item.sizeLabel ?? ''} ${item.voltage ?? ''}';
      return item.name.toLowerCase().contains(query) || (item.store ?? '').toLowerCase().contains(query) || (item.note ?? '').toLowerCase().contains(query) || details.toLowerCase().contains(query);
    }).toList();
    int priorityRank(String value) => switch (value) { 'muito' => 0, 'talvez' => 2, _ => 1 };
    switch (_sort) {
      case 'price_asc':
        items.sort((a, b) => (a.price ?? 1e12).compareTo(b.price ?? 1e12));
      case 'price_desc':
        items.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
      case 'name':
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'store':
        items.sort((a, b) => (a.store ?? '').toLowerCase().compareTo((b.store ?? '').toLowerCase()));
      case 'priority':
        items.sort((a, b) => priorityRank(a.priority).compareTo(priorityRank(b.priority)));
      case 'date':
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        items.sort((a, b) {
          final byPosition = a.position.compareTo(b.position);
          if (byPosition != 0) return byPosition;
          return a.createdAt.compareTo(b.createdAt);
        });
    }
    return items;
  }

  bool get _canReorder => (_list?.canEdit ?? false) && _sort == 'manual' && _query.trim().isEmpty && _priority == 'todas' && !_hidePurchased;

  List<String> _idsAfterMove(String? categoryId, int oldIndex, int newIndex) {
    final byCategory = <String?, List<WishItem>>{};
    for (final item in _items) {
      byCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }
    for (final group in byCategory.values) {
      group.sort((a, b) => a.position.compareTo(b.position));
    }
    final group = [...?byCategory[categoryId]];
    final moved = group.removeAt(oldIndex);
    group.insert(newIndex, moved);
    byCategory[categoryId] = group;
    final ids = <String>[];
    final seen = <String>{};
    final categories = [..._categories]..sort((a, b) => a.position.compareTo(b.position));
    for (final category in categories) {
      for (final item in byCategory[category.id] ?? const <WishItem>[]) {
        if (seen.add(item.id)) ids.add(item.id);
      }
    }
    for (final item in byCategory[null] ?? const <WishItem>[]) {
      if (seen.add(item.id)) ids.add(item.id);
    }
    for (final item in _items) {
      if (seen.add(item.id)) ids.add(item.id);
    }
    return ids;
  }

  Future<void> _reorderGroup(String? categoryId, int oldIndex, int newIndex) async {
    if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) return;
    final ids = _idsAfterMove(categoryId, oldIndex, newIndex);
    final rank = {for (var index = 0; index < ids.length; index++) ids[index]: index};
    setState(() => _items = [for (final item in _items) item.withPosition(rank[item.id] ?? item.position)]);
    try {
      await SessionScope.of(context).api.reorderItems(widget.listId, ids);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final session = SessionScope.of(context);
      final api = session.api;
      final cached = session.listsCache;
      final snapshotFuture = api.listItems(widget.listId);
      final listsFuture = cached != null ? Future<List<WishList>>.value(cached) : session.loadLists();
      final results = await Future.wait([snapshotFuture, listsFuture]);
      if (!mounted) return;
      final snapshot = results[0] as WishlistSnapshot;
      var lists = List<WishList>.from(results[1] as List<WishList>);
      final current = snapshot.list;
      if (current != null) {
        final known = lists.any((list) => list.id == current.id);
        lists = [for (final list in lists) list.id == current.id ? current : list];
        if (!known) lists = [current, ...lists];
        session.rememberLists(lists);
      }
      WishList? match;
      for (final candidate in lists) {
        if (candidate.id == widget.listId) match = candidate;
      }
      setState(() {
        _allLists = lists;
        _items = snapshot.items;
        _categories = snapshot.categories;
        _list = current ?? match;
        _loading = false;
        _loadedAt = DateTime.now();
        _error = (current ?? match) == null ? 'Lista não encontrada.' : null;
      });
      _armPoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : 'Não foi possível carregar os itens. Tente de novo.';
      });
    }
  }

  void _armPoll() {
    final pending = _items.any((item) => item.status == 'pending');
    if (!pending) {
      _poll?.cancel();
      _poll = null;
      _pollSince = null;
      return;
    }
    _pollSince ??= DateTime.now();
    _poll ??= Timer.periodic(const Duration(seconds: 2), (_) => _pollItems());
  }

  Future<void> _pollItems() async {
    final started = _pollSince;
    if (started != null && DateTime.now().difference(started) > const Duration(seconds: 30)) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    try {
      final snapshot = await SessionScope.of(context).api.listItems(widget.listId);
      if (!mounted) return;
      setState(() {
        _items = snapshot.items;
        _categories = snapshot.categories;
        if (snapshot.list != null) _list = snapshot.list;
      });
      _armPoll();
    } catch (_) {
      // The next tick tries again until the short poll window ends.
    }
  }

  void _insert(WishItem item) {
    setState(() => _items = [item, ..._items.where((current) => current.id != item.id)]);
    _armPoll();
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
      _armPoll();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(WishItem item) async {
    final updated = await showItemEditor(
      context,
      api: SessionScope.of(context).api,
      listId: widget.listId,
      item: item,
      categories: _categories,
      onCategoryCreated: (created) {
        if (mounted) setState(() => _categories = [..._categories, created]);
      },
    );
    if (updated != null) {
      _replace(updated);
      _armPoll();
    }
  }

  Future<void> _togglePurchased(WishItem item) async {
    setState(() => _busyId = item.id);
    try {
      final updated = await SessionScope.of(context).api.updateItem(item.id, purchased: !item.purchased);
      if (!mounted) return;
      _replace(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(WishItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.wishlyCream,
        title: Text('Excluir este item?', style: fraunces(WishlyText.xl2)),
        content: Text('“${item.name}” sai da lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: QueroColors.danger, foregroundColor: WishlyColor.white),
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
      final result = await SharePlus.instance.share(ShareParams(text: link, subject: 'Lista no Wishly'));
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
        backgroundColor: context.wishlyCream,
        title: Text('Compartilhar', style: fraunces(WishlyText.xl2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Quem abrir o link vê a lista e pode marcar “Já comprei”, sem entrar na sua conta.'),
            const SizedBox(height: WishlySpace.s3),
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
            child: Text('Revogar', style: TextStyle(color: context.wishlyDanger)),
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
        final wide = constraints.maxWidth >= WishlyBreak.lg;
        final narrow = constraints.maxWidth < WishlyBreak.sm;
        final canEdit = _list?.canEdit ?? false;
        final isOwner = _list?.isOwner == true;
        final board = _Board(
          title: name,
          items: _arranged(_items),
          loading: _loading,
          error: _error,
          busyId: _busyId,
          wide: wide,
          narrow: narrow,
          snapshot: _snapshot,
          categories: _categories,
          api: api,
          canEdit: canEdit,
          onAdd: canEdit ? () => _openAdd(api) : null,
          onAddInCategory: canEdit ? (categoryId) => _openAdd(api, categoryId: categoryId) : null,
          onCategories: canEdit ? _manageCategories : null,
          onMembers: _list == null ? null : _openMembers,
          onMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
          onBack: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
          onShare: isOwner ? _share : null,
          onRenameList: isOwner ? _renameList : null,
          onDeleteList: isOwner ? _deleteList : null,
          onReload: _load,
          onReserve: _reserve,
          onRefresh: _refresh,
          onEdit: _edit,
          onTogglePurchased: canEdit ? _togglePurchased : null,
          hidePurchased: _hidePurchased,
          onHidePurchased: (value) => setState(() => _hidePurchased = value),
          onDelete: _delete,
          onUnreserve: _clearReservation,
          budget: _list?.budget,
          budgetCurrency: _list?.budgetCurrency,
          query: _query,
          onQuery: (value) => setState(() => _query = value),
          sort: _sort,
          onSort: _setSort,
          priority: _priority,
          onPriority: (value) => setState(() => _priority = value),
          onReorder: _canReorder ? _reorderGroup : null,
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
          onMembers: _list == null ? null : _openMembers,
        );
        if (!wide) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: context.wishlyPaper,
            drawer: Drawer(backgroundColor: QueroColors.ink, child: sidebar),
            floatingActionButton: canEdit
                ? FloatingActionButton.extended(
                    onPressed: () => _openAdd(api),
                    backgroundColor: WishlyColor.accent,
                    foregroundColor: context.wishlyOnAccent,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                  )
                : null,
            body: board,
          );
        }
        return Scaffold(
          backgroundColor: context.wishlyPaper,
          body: Row(children: [sidebar, Expanded(child: board)]),
        );
      },
    );
  }

  Future<void> _openMembers() async {
    final list = _list;
    if (list == null) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
    final left = await showDialog<bool>(
      context: context,
      builder: (context) => MembersDialog(api: SessionScope.of(context).api, list: list),
    );
    if (!mounted) return;
    if (left == true) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      return;
    }
    await _load();
  }

  Future<void> _reserve(WishItem item) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: context.wishlyCream,
          title: Text('Já comprei', style: fraunces(WishlyText.xl2)),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Seu nome (opcional)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
              child: const Text('Reservar'),
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    setState(() => _busyId = item.id);
    try {
      final updated = await SessionScope.of(context).api.reserveItem(item.id, name: name);
      if (!mounted) return;
      _replace(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
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

  Future<void> _renameList() async {
    final list = _list;
    if (list == null) return;
    final name = await _askListName(context, title: 'Renomear lista', initial: list.name, confirm: 'Salvar');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await SessionScope.of(context).api.renameList(list.id, name);
      if (!mounted) return;
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteList() async {
    final list = _list;
    if (list == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.wishlyCream,
        title: Text('Excluir “${list.name}”?', style: fraunces(WishlyText.xl2)),
        content: const Text('A lista e os itens saem da sua conta. O link compartilhado deixa de funcionar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: QueroColors.danger, foregroundColor: WishlyColor.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await SessionScope.of(context).api.deleteList(list.id);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
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

  Future<void> _openAdd(QueroApi api, {String? categoryId}) async {
    final list = _list;
    if (list == null) return;
    final created = await showItemEditor(
      context,
      api: api,
      listId: list.id,
      categories: _categories,
      initialCategoryId: categoryId,
      onCategoryCreated: (category) {
        if (mounted) setState(() => _categories = [..._categories, category]);
      },
    );
    if (created != null) _insert(created);
  }
}

Future<String?> _askListName(BuildContext context, {String title = 'Nova lista', String initial = '', String confirm = 'Criar'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.wishlyCream,
      title: Text(title, style: fraunces(WishlyText.xl2)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Nome da lista')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
          child: Text(confirm),
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
    this.narrow = false,
    required this.snapshot,
    required this.categories,
    required this.api,
    required this.canEdit,
    this.onAdd,
    this.onAddInCategory,
    this.onCategories,
    this.onMembers,
    this.onMenu,
    required this.onBack,
    this.onShare,
    this.onRenameList,
    this.onDeleteList,
    required this.onReload,
    this.onReserve,
    required this.onRefresh,
    required this.onEdit,
    this.onTogglePurchased,
    required this.hidePurchased,
    required this.onHidePurchased,
    required this.onDelete,
    required this.onUnreserve,
    this.budget,
    this.budgetCurrency,
    this.query = '',
    this.onQuery,
    this.sort = 'manual',
    this.onSort,
    this.priority = 'todas',
    this.onPriority,
    this.onReorder,
  });

  final String title;
  final List<WishItem> items;
  final bool loading;
  final String? error;
  final String? busyId;
  final bool wide;
  final bool narrow;
  final WishlistSnapshot snapshot;
  final List<WishCategory> categories;
  final QueroApi api;
  final bool canEdit;
  final VoidCallback? onAdd;
  final void Function(String? categoryId)? onAddInCategory;
  final VoidCallback? onCategories;
  final VoidCallback? onMembers;
  final VoidCallback? onMenu;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback? onRenameList;
  final VoidCallback? onDeleteList;
  final Future<void> Function() onReload;
  final void Function(WishItem)? onReserve;
  final void Function(WishItem) onRefresh;
  final void Function(WishItem) onEdit;
  final void Function(WishItem)? onTogglePurchased;
  final bool hidePurchased;
  final ValueChanged<bool> onHidePurchased;
  final void Function(WishItem) onDelete;
  final void Function(WishItem) onUnreserve;
  final double? budget;
  final String? budgetCurrency;
  final String query;
  final ValueChanged<String>? onQuery;
  final String sort;
  final ValueChanged<String>? onSort;
  final String priority;
  final ValueChanged<String>? onPriority;
  final void Function(String? categoryId, int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    if (narrow) return _narrowBoard(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? WishlySpace.s8 : WishlySpace.s4, wide ? WishlySpace.s5 : WishlySpace.s2, wide ? WishlySpace.s8 : WishlySpace.s4, WishlySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (onMenu != null) IconButton(onPressed: onMenu, tooltip: 'Listas', icon: const Icon(Icons.menu)),
                if (!wide && onMenu == null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                Expanded(child: Text(wide ? 'Itens' : title, style: fraunces(wide ? WishlyText.xl3 : WishlyText.xl2))),
                if (wide && onAdd != null)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                    style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
                  ),
                if (onMembers != null) IconButton(onPressed: onMembers, tooltip: 'Membros', icon: const Icon(Icons.group_outlined)),
                if (onCategories != null) IconButton(onPressed: onCategories, tooltip: 'Categorias', icon: const Icon(Icons.category_outlined)),
                if (onShare != null) IconButton(onPressed: onShare, tooltip: 'Compartilhar', icon: const Icon(Icons.ios_share)),
                const _Bell(),
                IconButton(onPressed: onReload, tooltip: 'Recarregar', icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          if (!wide) _TotalBlock(snapshot: snapshot, onDark: false, budget: budget, budgetCurrency: budgetCurrency),
          _FindSort(query: query, onQuery: onQuery, sort: sort, onSort: onSort, priority: priority, onPriority: onPriority),
          const SizedBox(height: WishlySpace.s2),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _narrowBoard(BuildContext context) {
    return RefreshIndicator(
      color: QueroColors.ink,
      onRefresh: onReload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: context.wishlyPaper,
            surfaceTintColor: context.wishlyPaper,
            foregroundColor: context.wishlyInk,
            elevation: WishlyElevation.none,
            scrolledUnderElevation: WishlyElevation.none,
            toolbarHeight: kToolbarHeight,
            expandedHeight: kToolbarHeight + WishlySize.headerExtra,
            leading: IconButton(onPressed: onMenu, tooltip: 'Listas', icon: const Icon(Icons.menu)),
            actions: [
              const _Bell(),
              if (onShare != null) IconButton(onPressed: onShare, tooltip: 'Compartilhar', icon: const Icon(Icons.ios_share)),
              PopupMenuButton<String>(
                tooltip: 'Mais',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'members':
                      onMembers?.call();
                    case 'categories':
                      onCategories?.call();
                    case 'rename':
                      onRenameList?.call();
                    case 'delete':
                      onDeleteList?.call();
                    case 'refresh':
                      onReload();
                    default:
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onMembers != null) const PopupMenuItem(value: 'members', child: Text('Membros')),
                  if (onCategories != null) const PopupMenuItem(value: 'categories', child: Text('Categorias')),
                  if (onRenameList != null) const PopupMenuItem(value: 'rename', child: Text('Renomear lista')),
                  if (onDeleteList != null)
                    PopupMenuItem(value: 'delete', child: Text('Excluir lista', style: TextStyle(color: context.wishlyDanger))),
                  const PopupMenuItem(value: 'refresh', child: Text('Atualizar')),
                ],
              ),
            ],
            flexibleSpace: _CollapsingListTitle(title: title),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s1, WishlySpace.s4, WishlySpace.s2),
              child: _TotalBlock(snapshot: snapshot, onDark: false, budget: budget, budgetCurrency: budgetCurrency),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4),
              child: _FindSort(query: query, onQuery: onQuery, sort: sort, onSort: onSort, priority: priority, onPriority: onPriority),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s1, WishlySpace.s4, WishlySpace.s16 + WishlySpace.s12),
            sliver: _narrowBody(context),
          ),
        ],
      ),
    );
  }

  Widget _narrowBody(BuildContext context) {
    if (loading) {
      return const SliverFillRemaining(hasScrollBody: false, child: PageSkeleton(cards: 2));
    }
    if (error != null && items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s6), child: Text(error!, textAlign: TextAlign.center)),
              const SizedBox(height: WishlySpace.s4),
              OutlinedButton(onPressed: onReload, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty && categories.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: const EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.'),
      );
    }
    if (categories.isEmpty) {
      final shown = hidePurchased ? items.where((item) => !item.purchased).toList() : items;
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _hideChip(context)),
          if (shown.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.'))
          else if (onReorder != null)
            SliverToBoxAdapter(child: ReorderableItemList(items: shown, wide: false, onReorder: (oldIndex, newIndex) => onReorder!(null, oldIndex, newIndex), cardBuilder: _card))
          else
            SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (context, index) => const SizedBox(height: WishlySpace.s4),
              itemBuilder: (context, index) => _card(shown[index]),
            ),
        ],
      );
    }
    return SliverToBoxAdapter(
      child: GroupedItems(
        categories: categories,
        items: items,
        wide: false,
        embedded: true,
        hidePurchased: hidePurchased,
        onHidePurchased: onHidePurchased,
        onAddInCategory: onAddInCategory,
        keepOrder: true,
        onReorder: onReorder,
        cardBuilder: (item, fill) => _card(item),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (loading) return const PageSkeleton(cards: 2);
    if (error != null && items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s6), child: Text(error!, textAlign: TextAlign.center)),
            const SizedBox(height: WishlySpace.s4),
            OutlinedButton(onPressed: onReload, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    if (items.isEmpty && categories.isEmpty) {
      return _pull(context, ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.')]));
    }
    final shown = hidePurchased ? items.where((item) => !item.purchased).toList() : items;
    if (categories.isEmpty) {
      final body = shown.isEmpty
          ? const EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.')
          : onReorder != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [ReorderableItemList(items: shown, wide: wide, onReorder: (oldIndex, newIndex) => onReorder!(null, oldIndex, newIndex), cardBuilder: _card)],
                )
              : wide
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [ItemWrap(count: shown.length, itemBuilder: (index) => _card(shown[index]))],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: shown.length,
                      separatorBuilder: (context, index) => const SizedBox(height: WishlySpace.s4),
                      itemBuilder: (context, index) => _card(shown[index]),
                    );
      return _pull(context, Column(children: [_hideChip(context), Expanded(child: body)]));
    }
    return GroupedItems(
      categories: categories,
      items: items,
      wide: wide,
      onRefresh: onReload,
      hidePurchased: hidePurchased,
      onHidePurchased: onHidePurchased,
      onAddInCategory: onAddInCategory,
      keepOrder: true,
      onReorder: onReorder,
      cardBuilder: (item, fill) => _card(item),
    );
  }

  Widget _hideChip(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        label: const Text('Ocultar comprados'),
        selected: hidePurchased,
        onSelected: onHidePurchased,
        selectedColor: context.wishlyChip,
        checkmarkColor: context.wishlyInk,
        labelStyle: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pull(BuildContext context, Widget child) {
    return RefreshIndicator(color: context.wishlyInk, onRefresh: onReload, child: child);
  }

  Widget _card(WishItem item) {
    final viewer = !canEdit;
    return ItemCard(
      item: item,
      proxyUrl: api.imageProxy(item),
      imageHeaders: api.authHeaders,
      busy: busyId == item.id,
      readOnly: viewer,
      onRefresh: () => onRefresh(item),
      onEdit: () => onEdit(item),
      onTogglePurchased: onTogglePurchased == null ? null : () => onTogglePurchased!(item),
      onDelete: () => onDelete(item),
      onReserve: viewer && !item.reserved && onReserve != null ? () => onReserve!(item) : null,
      onUnreserve: item.reserved && (viewer ? item.reservedByMe : true) ? () => onUnreserve(item) : null,
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
        backgroundColor: context.wishlyCream,
        title: Text('Excluir “${category.name}”?', style: fraunces(WishlyText.xl2)),
        content: const Text('Os itens dessa categoria passam para Sem categoria.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: QueroColors.danger, foregroundColor: WishlyColor.white),
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
      backgroundColor: context.wishlyCream,
      title: Text('Categorias', style: fraunces(WishlyText.xl2)),
      content: SizedBox(
        width: WishlySize.field,
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
                  TextButton(onPressed: () => _delete(_categories[i]), child: Text('Excluir', style: TextStyle(color: context.wishlyDanger))),
                ],
              ),
            const SizedBox(height: WishlySpace.s2),
            TextField(
              controller: _name,
              style: TextStyle(color: context.wishlyInk),
              cursorColor: WishlyColor.accent,
              decoration: wishlyField(context, hint: 'Nova categoria'),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: WishlySpace.s2), child: Text(_error!, style: TextStyle(color: context.wishlyDanger))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _add,
          style: FilledButton.styleFrom(
            backgroundColor: WishlyColor.accent,
            foregroundColor: context.wishlyOnAccent,
            disabledBackgroundColor: context.wishlyLine,
            disabledForegroundColor: context.wishlyInk,
          ),
          child: const Text('Adicionar'),
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
      backgroundColor: context.wishlyCream,
      title: Text('Renomear', style: fraunces(WishlyText.xl2)),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

class _CollapsingListTitle extends StatelessWidget {
  const _CollapsingListTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final span = settings == null ? 1.0 : settings.maxExtent - settings.minExtent;
    final expanded = settings == null || span <= 0 ? 1.0 : ((settings.currentExtent - settings.minExtent) / span).clamp(0.0, 1.0);
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (expanded > 0.2)
          Positioned(
            left: WishlySpace.s4,
            right: WishlySpace.s4,
            bottom: WishlySpace.s2,
            child: Opacity(
              opacity: expanded,
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true, style: fraunces(WishlyText.xl3, height: WishlyText.snug)),
            ),
          ),
        if (expanded < 0.55)
          Positioned(
            left: WishlySize.collapsedStart,
            right: WishlySize.collapsedEnd,
            top: top,
            height: kToolbarHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: (1 - expanded).clamp(0.0, 1.0),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: fraunces(WishlyText.lg, height: WishlyText.tight)),
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.snapshot, required this.onDark, this.budget, this.budgetCurrency});
  final WishlistSnapshot snapshot;
  final bool onDark;
  final double? budget;
  final String? budgetCurrency;

  @override
  Widget build(BuildContext context) {
    final label = onDark ? WishlyColor.onInkMuted : context.wishlyMuted;
    final value = onDark ? WishlyColor.cream : context.wishlyForest;
    final totals = snapshot.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FALTA COMPRAR', style: TextStyle(color: label, fontSize: WishlyText.xs, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w600)),
        const SizedBox(height: WishlySpace.s2),
        if (totals.isEmpty)
          Text(snapshot.purchasedTotals.isEmpty ? 'Sem preços para somar' : 'Nada pendente', style: TextStyle(color: value, fontSize: WishlyText.lg, fontWeight: FontWeight.w600))
        else
          for (final total in totals)
            Text(formatMoney(total.amount, total.currency.isEmpty ? null : total.currency), style: fraunces(onDark ? WishlyText.xl3 : WishlyText.xl2, color: value)),
        if (budget != null && budget! > 0) ...[
          const SizedBox(height: WishlySpace.s2),
          Text('ORÇAMENTO', style: TextStyle(color: label, fontSize: WishlyText.xs, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w600)),
          const SizedBox(height: WishlySpace.s1),
          LinearProgressIndicator(
            value: ((snapshot.purchasedTotals.isEmpty ? 0 : snapshot.purchasedTotals.first.amount) / budget!).clamp(0, 1).toDouble(),
            minHeight: WishlySpace.s2,
            color: onDark ? WishlyColor.cream : context.wishlyForest,
            backgroundColor: onDark ? WishlyColor.inkLine : context.wishlyLine,
            borderRadius: BorderRadius.circular(WishlyRadius.full),
          ),
          Text('Comprado de ${formatMoney(budget!, budgetCurrency)}', style: TextStyle(color: label, fontSize: WishlyText.xs)),
        ],
        if (snapshot.purchasedTotals.isNotEmpty) ...[
          const SizedBox(height: WishlySpace.s2),
          Text('JÁ COMPRADO', style: TextStyle(color: label, fontSize: WishlyText.xs, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w600)),
          for (final total in snapshot.purchasedTotals)
            Text(
              formatMoney(total.amount, total.currency.isEmpty ? null : total.currency),
              style: TextStyle(color: label, fontSize: onDark ? WishlyText.lg : WishlyText.base, decoration: TextDecoration.lineThrough),
            ),
        ],
      ],
    );
  }
}

class _FindSort extends StatefulWidget {
  const _FindSort({required this.query, required this.sort, required this.priority, this.onQuery, this.onSort, this.onPriority});

  final String query;
  final String sort;
  final String priority;
  final ValueChanged<String>? onQuery;
  final ValueChanged<String>? onSort;
  final ValueChanged<String>? onPriority;

  @override
  State<_FindSort> createState() => _FindSortState();
}

class _FindSortState extends State<_FindSort> {
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: WishlySpace.s2, bottom: WishlySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  style: TextStyle(color: context.wishlyInk),
                  cursorColor: WishlyColor.accent,
                  decoration: wishlyField(context, hint: 'Buscar nome, loja ou nota', dense: true),
                  onChanged: widget.onQuery,
                ),
              ),
              const SizedBox(width: WishlySpace.s2),
              DropdownButton<String>(
                value: widget.sort,
                dropdownColor: context.wishlyCream,
                style: TextStyle(color: context.wishlyInk, fontSize: WishlyText.base),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  DropdownMenuItem(value: 'price_asc', child: Text('Preço ↑')),
                  DropdownMenuItem(value: 'price_desc', child: Text('Preço ↓')),
                  DropdownMenuItem(value: 'date', child: Text('Data')),
                  DropdownMenuItem(value: 'store', child: Text('Loja')),
                  DropdownMenuItem(value: 'name', child: Text('Nome')),
                  DropdownMenuItem(value: 'priority', child: Text('Prioridade')),
                ],
                onChanged: (value) {
                  if (value != null) widget.onSort?.call(value);
                },
              ),
            ],
          ),
          const SizedBox(height: WishlySpace.s2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final choice in const [('todas', 'Todas'), ('muito', 'Quero muito'), ('quero', 'Quero'), ('talvez', 'Talvez')])
                  Padding(
                    padding: const EdgeInsets.only(right: WishlySpace.s2),
                    child: FilterChip(
                      label: Text(choice.$2),
                      selected: widget.priority == choice.$1,
                      onSelected: (_) => widget.onPriority?.call(choice.$1),
                      selectedColor: context.wishlyChip,
                      checkmarkColor: context.wishlyInk,
                      labelStyle: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bell extends StatefulWidget {
  const _Bell();

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> {
  int _unread = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await SessionScope.of(context).api.notifications();
      if (mounted) setState(() => _unread = notes.unread);
    } catch (_) {}
  }

  Future<void> _open() async {
    final api = SessionScope.of(context).api;
    final notes = await api.notifications();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.wishlyCream,
        title: Text('Avisos', style: fraunces(WishlyText.xl2)),
        content: SizedBox(
          width: WishlySize.field,
          child: notes.items.isEmpty
              ? const Text('Nenhuma queda de preço por aqui.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final note in notes.items.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: WishlySpace.s3),
                        child: Text('${note['title']}\n${note['body']}', style: const TextStyle(fontSize: WishlyText.sm, height: WishlyText.body)),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
    await api.readNotifications();
    if (mounted) setState(() => _unread = 0);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Avisos',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_outlined, size: WishlyIcon.lg),
      ),
    );
  }
}
