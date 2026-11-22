import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'grouped_items.dart';
import 'list_sidebar.dart';
import 'members_dialog.dart';
import 'widgets/add_form.dart';
import 'widgets/edit_dialog.dart';
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
    _load();
  }

  WishlistSnapshot get _snapshot => WishlistSnapshot(items: _items, unpricedCount: _items.where((item) => item.price == null).length, title: _list?.name);

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
        backgroundColor: QueroColors.cream,
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
        backgroundColor: QueroColors.cream,
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
        final wide = constraints.maxWidth >= WishlyBreak.lg;
        final narrow = constraints.maxWidth < WishlyBreak.sm;
        final canEdit = _list?.canEdit ?? false;
        final isOwner = _list?.isOwner == true;
        final board = _Board(
          title: name,
          items: _items,
          loading: _loading,
          error: _error,
          busyId: _busyId,
          wide: wide,
          narrow: narrow,
          snapshot: _snapshot,
          categories: _categories,
          api: api,
          canEdit: canEdit,
          onAdd: canEdit ? () => _openAdd(api, wide: wide) : null,
          onAddInCategory: canEdit ? (categoryId) => _openAdd(api, wide: wide, categoryId: categoryId) : null,
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
            backgroundColor: QueroColors.paper,
            drawer: Drawer(backgroundColor: QueroColors.ink, child: sidebar),
            floatingActionButton: canEdit
                ? FloatingActionButton.extended(
                    onPressed: () => _openAdd(api, wide: false),
                    backgroundColor: QueroColors.accent,
                    foregroundColor: WishlyColor.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                  )
                : null,
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
          backgroundColor: QueroColors.cream,
          title: Text('Já comprei', style: fraunces(WishlyText.xl2)),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Seu nome (opcional)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
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
        backgroundColor: QueroColors.cream,
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

  Future<void> _openAdd(QueroApi api, {required bool wide, String? categoryId}) async {
    final list = _list;
    if (list == null) return;
    final panel = AddPanel(
      api: api,
      listId: list.id,
      categories: _categories,
      initialCategoryId: categoryId,
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
          padding: EdgeInsets.fromLTRB(WishlySpace.s5, WishlySpace.s4, WishlySpace.s5, WishlySpace.s5 + MediaQuery.viewInsetsOf(context).bottom),
          child: panel,
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: QueroColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.xl2)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: WishlySize.sheet),
          child: Padding(padding: const EdgeInsets.fromLTRB(WishlySpace.s6, WishlySpace.s5, WishlySpace.s6, WishlySpace.s6), child: panel),
        ),
      ),
    );
  }
}

Future<String?> _askListName(BuildContext context, {String title = 'Nova lista', String initial = '', String confirm = 'Criar'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: QueroColors.cream,
      title: Text(title, style: fraunces(WishlyText.xl2)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Nome da lista')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
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

  @override
  Widget build(BuildContext context) {
    if (narrow) return _narrowBoard();
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
                    style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
                  ),
                if (onMembers != null) IconButton(onPressed: onMembers, tooltip: 'Membros', icon: const Icon(Icons.group_outlined)),
                if (onCategories != null) IconButton(onPressed: onCategories, tooltip: 'Categorias', icon: const Icon(Icons.category_outlined)),
                if (onShare != null) IconButton(onPressed: onShare, tooltip: 'Compartilhar', icon: const Icon(Icons.ios_share)),
                IconButton(onPressed: onReload, tooltip: 'Recarregar', icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          if (!wide) _TotalBlock(snapshot: snapshot, onDark: false),
          const SizedBox(height: WishlySpace.s2),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _narrowBoard() {
    return RefreshIndicator(
      color: QueroColors.ink,
      onRefresh: onReload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: QueroColors.paper,
            surfaceTintColor: QueroColors.paper,
            foregroundColor: QueroColors.ink,
            elevation: WishlyElevation.none,
            scrolledUnderElevation: WishlyElevation.none,
            toolbarHeight: kToolbarHeight,
            expandedHeight: kToolbarHeight + WishlySize.headerExtra,
            leading: IconButton(onPressed: onMenu, tooltip: 'Listas', icon: const Icon(Icons.menu)),
            actions: [
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
                    const PopupMenuItem(value: 'delete', child: Text('Excluir lista', style: TextStyle(color: QueroColors.danger))),
                  const PopupMenuItem(value: 'refresh', child: Text('Atualizar')),
                ],
              ),
            ],
            flexibleSpace: _CollapsingListTitle(title: title),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s1, WishlySpace.s4, WishlySpace.s2),
              child: _TotalBlock(snapshot: snapshot, onDark: false),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s1, WishlySpace.s4, WishlySpace.s16 + WishlySpace.s12),
            sliver: _narrowBody(),
          ),
        ],
      ),
    );
  }

  Widget _narrowBody() {
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
      final shown = sortedWishItems(hidePurchased ? items.where((item) => !item.purchased) : items);
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _hideChip()),
          if (shown.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.'))
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
        cardBuilder: (item, fill) => _card(item),
      ),
    );
  }

  Widget _content() {
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
      return _pull(ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.')]));
    }
    final shown = sortedWishItems(hidePurchased ? items.where((item) => !item.purchased) : items);
    if (categories.isEmpty) {
      final body = shown.isEmpty
          ? const EmptyState(title: 'Nada por aqui ainda', message: 'Cole o link de um produto para guardar a foto e o preço.')
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
      return _pull(Column(children: [_hideChip(), Expanded(child: body)]));
    }
    return GroupedItems(
      categories: categories,
      items: items,
      wide: wide,
      onRefresh: onReload,
      hidePurchased: hidePurchased,
      onHidePurchased: onHidePurchased,
      onAddInCategory: onAddInCategory,
      cardBuilder: (item, fill) => _card(item),
    );
  }

  Widget _hideChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        label: const Text('Ocultar comprados'),
        selected: hidePurchased,
        onSelected: onHidePurchased,
        selectedColor: WishlyTokens.chip,
        checkmarkColor: QueroColors.ink,
        labelStyle: const TextStyle(color: QueroColors.ink, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pull(Widget child) {
    return RefreshIndicator(color: QueroColors.ink, onRefresh: onReload, child: child);
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
        backgroundColor: QueroColors.cream,
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
      backgroundColor: QueroColors.cream,
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
                  TextButton(onPressed: () => _delete(_categories[i]), child: const Text('Excluir', style: TextStyle(color: QueroColors.danger))),
                ],
              ),
            const SizedBox(height: WishlySpace.s2),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Nova categoria'),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: WishlySpace.s2), child: Text(_error!, style: const TextStyle(color: QueroColors.danger))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _add,
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
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
      backgroundColor: QueroColors.cream,
      title: Text('Renomear', style: fraunces(WishlyText.xl2)),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
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
  const _TotalBlock({required this.snapshot, required this.onDark});
  final WishlistSnapshot snapshot;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final label = onDark ? WishlyTokens.onInkMuted : QueroColors.muted;
    final value = onDark ? QueroColors.cream : QueroColors.forest;
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
