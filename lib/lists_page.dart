import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/member_avatars.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = _lists.isEmpty;
      _error = null;
    });
    try {
      final lists = await SessionScope.of(context).api.lists();
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
        title: Text('Excluir “${list.name}”?', style: fraunces(24)),
        content: const Text('A lista e os itens saem da sua conta. O link compartilhado deixa de funcionar.'),
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
      await SessionScope.of(context).api.deleteList(list.id);
      if (!mounted) return;
      setState(() => _lists = _lists.where((current) => current.id != list.id).toList());
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
                padding: const EdgeInsets.fromLTRB(24, 18, 8, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wishly', style: fraunces(32, style: FontStyle.italic, color: QueroColors.cream)),
                          Text(email, style: const TextStyle(color: Color(0xFFD7CDC2), fontSize: 13)),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Suas listas', style: fraunces(32)),
                      const Spacer(),
                      FilledButton(
                        onPressed: _create,
                        style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
                        child: const Text('Nova lista'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: QueroColors.ink));
    if (_error != null && _lists.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Tentar de novo'))]));
    }
    if (_lists.isEmpty) {
      return Center(child: Text('Nenhuma lista ainda', style: fraunces(28)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (!wide) {
          return ListView.separated(
            itemCount: _lists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _card(_lists[index]),
          );
        }
        return GridView.builder(
          itemCount: _lists.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14),
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed('/list/${list.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: fraunces(24))),
                  if (list.collaborative) const SharedBadge(),
                ],
              ),
              if (list.collaborative) ...[
                const SizedBox(height: 8),
                MemberAvatars(members: list.members),
              ],
              const SizedBox(height: 6),
              Text(list.itemCount == 1 ? '1 item' : '${list.itemCount} itens', style: const TextStyle(color: QueroColors.muted)),
              const SizedBox(height: 8),
              Text('Falta comprar $total', style: fraunces(20, color: QueroColors.forest)),
              if (bought != null) Text('Já comprado $bought', style: const TextStyle(color: QueroColors.muted, decoration: TextDecoration.lineThrough)),
              Row(
                children: [
                  if (!list.collaborative && list.shareToken != null)
                    const Text('Link público', style: TextStyle(color: QueroColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
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
      title: Text(title, style: fraunces(24)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Nome da lista')),
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
