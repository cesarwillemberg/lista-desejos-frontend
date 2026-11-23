import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'grouped_items.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_card.dart';
import 'widgets/skeleton.dart';

class SharedPage extends StatefulWidget {
  const SharedPage({super.key, required this.token});

  final String token;

  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  WishlistSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  String? _busyId;
  var _hidePurchased = false;

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() => _error = null);
    try {
      final snapshot = await session.api.sharedList(widget.token, claims: session.claimHeader);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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
    final session = SessionScope.of(context);
    try {
      final claim = await session.api.reserve(widget.token, item.id, name: name);
      await session.rememberClaim(item.id, claim);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _unreserve(WishItem item) async {
    final session = SessionScope.of(context);
    final claim = session.claimMap[item.id];
    if (claim == null) return;
    setState(() => _busyId = item.id);
    try {
      await session.api.clearReservation(widget.token, item.id, claim);
      await session.forgetClaim(item.id);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    final snapshot = _snapshot;
    final title = snapshot?.title ?? 'Lista compartilhada';
    return Scaffold(
      backgroundColor: context.wishlyPaper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: QueroColors.ink,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(WishlySpace.s5, WishlySpace.s4, WishlySpace.s5, WishlySpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wishly', style: fraunces(WishlyText.xl3, style: FontStyle.italic, color: QueroColors.cream)),
                    const SizedBox(height: WishlySpace.s1),
                    const Text('Lista compartilhada · só leitura', style: TextStyle(color: WishlyTokens.onInk)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WishlySpace.s4, WishlySpace.s4, WishlySpace.s4, WishlySpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: fraunces(WishlyText.xl3)),
                  if (snapshot != null) ...[
                    const SizedBox(height: WishlySpace.s2),
                    Text(
                      'Falta comprar ${snapshot.totals.isEmpty ? (snapshot.purchasedTotals.isEmpty ? 'sem preços' : 'nada pendente') : formatMoney(snapshot.totals.first.amount, snapshot.totals.first.currency.isEmpty ? null : snapshot.totals.first.currency)}',
                      style: fraunces(WishlyText.xl2, color: context.wishlyForest),
                    ),
                    if (snapshot.purchasedTotals.isNotEmpty)
                      Text(
                        'Já comprado ${formatMoney(snapshot.purchasedTotals.first.amount, snapshot.purchasedTotals.first.currency.isEmpty ? null : snapshot.purchasedTotals.first.currency)}',
                        style: TextStyle(color: context.wishlyMuted, decoration: TextDecoration.lineThrough),
                      ),
                  ],
                  const SizedBox(height: WishlySpace.s3),
                  Expanded(child: _body(api)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(QueroApi api) {
    if (_loading) return const PageSkeleton();
    if (_error != null) return Center(child: Text(_error!, textAlign: TextAlign.center));
    final items = _snapshot?.items ?? [];
    final categories = _snapshot?.categories ?? const <WishCategory>[];
    if (items.isEmpty && categories.isEmpty) return const EmptyState(title: 'Nada por aqui ainda', message: 'Esta lista ainda não tem itens.');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= WishlyBreak.lg;
        Widget card(WishItem item, {bool fillHeight = false}) {
          return ItemCard(
            item: item,
            proxyUrl: api.sharedImageProxy(widget.token, item),
            busy: _busyId == item.id,
            readOnly: true,
            onRefresh: () {},
            onEdit: () {},
            onDelete: () {},
            onReserve: () => _reserve(item),
            onUnreserve: item.reservedByMe ? () => _unreserve(item) : null,
            fillHeight: fillHeight,
          );
        }
        final shown = sortedWishItems(_hidePurchased ? items.where((item) => !item.purchased) : items);
        if (categories.isNotEmpty) {
          return GroupedItems(
            categories: categories,
            items: items,
            wide: wide,
            hidePurchased: _hidePurchased,
            onHidePurchased: (value) => setState(() => _hidePurchased = value),
            cardBuilder: (item, fill) => card(item, fillHeight: fill),
          );
        }
        final list = !wide
            ? ListView.separated(
                itemCount: shown.length,
                separatorBuilder: (context, index) => const SizedBox(height: WishlySpace.s4),
                itemBuilder: (context, index) => card(shown[index]),
              )
            : ListView(children: [ItemWrap(count: shown.length, itemBuilder: (index) => card(shown[index], fillHeight: true))]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterChip(
              label: const Text('Ocultar comprados'),
              selected: _hidePurchased,
              onSelected: (value) => setState(() => _hidePurchased = value),
              selectedColor: context.wishlyChip,
              checkmarkColor: context.wishlyInk,
              labelStyle: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: WishlySpace.s2),
            Expanded(child: shown.isEmpty ? const EmptyState(title: 'Nada por aqui ainda', message: 'Esta lista ainda não tem itens.') : list),
          ],
        );
      },
    );
  }
}
