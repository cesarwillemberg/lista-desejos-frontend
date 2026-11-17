import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/member_avatars.dart';
import 'widgets/skeleton.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  List<WishList> _lists = [];
  bool _loading = true;
  String? _error;

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final session = SessionScope.of(context);
    final cached = force ? null : session.listsCache;
    setState(() {
      _loading = cached == null && _lists.isEmpty;
      _error = null;
      if (cached != null) _lists = cached;
    });
    if (cached != null) return;
    try {
      final lists = await session.loadLists(force: force);
      if (!mounted) return;
      setState(() {
        _lists = lists;
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

  Future<void> _create() async {
    final name = await _askName(context, title: 'Nova lista', initial: '');
    if (name == null || !mounted) return;
    try {
      final created = await SessionScope.of(context).api.createList(name);
      if (!mounted) return;
      setState(() => _lists = [created, ..._lists.where((list) => list.id != created.id)]);
      SessionScope.of(context).rememberLists(_lists);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _rename(WishList list) async {
    final name = await _askName(context, title: 'Renomear lista', initial: list.name);
    if (name == null || !mounted) return;
    try {
      final updated = await SessionScope.of(context).api.renameList(list.id, name);
      if (!mounted) return;
      setState(() => _lists = [for (final current in _lists) current.id == list.id ? updated : current]);
      SessionScope.of(context).rememberLists(_lists);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(WishList list) async {
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
      setState(() => _lists = _lists.where((current) => current.id != list.id).toList());
      SessionScope.of(context).rememberLists(_lists);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _logout() async {
    await SessionScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = SessionScope.of(context).user?.email ?? '';
    return Scaffold(
      backgroundColor: QueroColors.paper,
      body: Column(
        children: [
          ColoredBox(
            color: QueroColors.ink,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(WishlySpace.s6, WishlySpace.s5, WishlySpace.s2, WishlySpace.s5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wishly', style: fraunces(WishlyText.xl3, style: FontStyle.italic, color: QueroColors.cream)),
                          Text(email, style: const TextStyle(color: WishlyTokens.onInk, fontSize: WishlyText.sm)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: _logout, child: const Text('Sair', style: TextStyle(color: QueroColors.cream))),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WishlySpace.s5, WishlySpace.s5, WishlySpace.s5, WishlySpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Suas listas', style: fraunces(WishlyText.xl3)),
                      const Spacer(),
                      FilledButton(
                        onPressed: _create,
                        style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
                        child: const Text('Nova lista'),
                      ),
                    ],
                  ),
                  const SizedBox(height: WishlySpace.s4),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const PageSkeleton();
    if (_error != null && _lists.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: WishlySpace.s3), OutlinedButton(onPressed: _load, child: const Text('Tentar de novo'))]));
    }
    if (_lists.isEmpty) {
      return const EmptyState(title: 'Nenhuma lista ainda', message: 'Crie a primeira e comece a guardar o que você quer.', icon: Icons.playlist_add_outlined);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= WishlyBreak.md;
        if (!wide) {
          return ListView.separated(
            itemCount: _lists.length,
            separatorBuilder: (context, index) => const SizedBox(height: WishlySpace.s3),
            itemBuilder: (context, index) => _card(_lists[index]),
          );
        }
        return GridView.builder(
          itemCount: _lists.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: WishlySize.listCard, mainAxisExtent: WishlySize.listCardHeight, crossAxisSpacing: WishlySpace.s4, mainAxisSpacing: WishlySpace.s4),
          itemBuilder: (context, index) => _card(_lists[index]),
        );
      },
    );
  }

  Widget _card(WishList list) {
    final total = list.totals.isEmpty
        ? (list.purchasedTotals.isEmpty ? 'Sem preços para somar' : 'Nada pendente')
        : formatMoney(list.totals.first.amount, list.totals.first.currency.isEmpty ? null : list.totals.first.currency);
    final bought = list.purchasedTotals.isEmpty ? null : formatMoney(list.purchasedTotals.first.amount, list.purchasedTotals.first.currency.isEmpty ? null : list.purchasedTotals.first.currency);
    return Material(
      color: QueroColors.cream,
      borderRadius: BorderRadius.circular(WishlyRadius.xl2),
      child: InkWell(
        borderRadius: BorderRadius.circular(WishlyRadius.xl2),
        onTap: () => Navigator.of(context).pushNamed('/list/${list.id}'),
        child: Padding(
          padding: const EdgeInsets.all(WishlySpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: fraunces(WishlyText.xl2))),
                  if (list.collaborative) const SharedBadge(),
                ],
              ),
              if (list.collaborative) ...[
                const SizedBox(height: WishlySpace.s2),
                MemberAvatars(members: list.members),
              ],
              const SizedBox(height: WishlySpace.s2),
              Text(list.itemCount == 1 ? '1 item' : '${list.itemCount} itens', style: const TextStyle(color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              Text('Falta comprar $total', style: fraunces(WishlyText.xl, color: QueroColors.forest)),
              if (bought != null) Text('Já comprado $bought', style: const TextStyle(color: QueroColors.muted, decoration: TextDecoration.lineThrough)),
              Row(
                children: [
                  if (!list.collaborative && list.shareToken != null)
                    const Text('Link público', style: TextStyle(color: QueroColors.accent, fontWeight: FontWeight.w700, fontSize: WishlyText.xs)),
                  const Spacer(),
                  if (list.isOwner) ...[
                    TextButton(onPressed: () => _rename(list), child: const Text('Renomear')),
                    TextButton(onPressed: () => _delete(list), child: const Text('Excluir', style: TextStyle(color: QueroColors.danger))),
                  ] else
                    Text(roleLabel(list.role), style: const TextStyle(color: QueroColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, {required String title, required String initial}) {
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
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
