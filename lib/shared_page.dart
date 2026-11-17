import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'money.dart';
import 'session.dart';
import 'theme.dart';
import 'grouped_items.dart';
import 'widgets/item_card.dart';

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
          backgroundColor: QueroColors.cream,
          title: Text('Já comprei', style: fraunces(26)),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Seu nome (opcional)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
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

  Future<void> _open(WishItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    final snapshot = _snapshot;
    final title = snapshot?.title ?? 'Lista compartilhada';
    return Scaffold(
      backgroundColor: QueroColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: QueroColors.ink,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quero', style: fraunces(28, style: FontStyle.italic, color: QueroColors.cream)),
                    const SizedBox(height: 4),
                    const Text('Lista compartilhada · só leitura', style: TextStyle(color: Color(0xFFD7CDC2))),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: fraunces(32)),
                  if (snapshot != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      snapshot.totals.isEmpty ? 'Sem preços para somar' : formatMoney(snapshot.totals.first.amount, snapshot.totals.first.currency.isEmpty ? null : snapshot.totals.first.currency),
                      style: fraunces(26, color: QueroColors.forest),
                    ),
                  ],
                  const SizedBox(height: 12),
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: QueroColors.ink));
    if (_error != null) return Center(child: Text(_error!, textAlign: TextAlign.center));
    final items = _snapshot?.items ?? [];
    final categories = _snapshot?.categories ?? const <WishCategory>[];
    if (items.isEmpty && categories.isEmpty) return Center(child: Text('Nada por aqui ainda', style: fraunces(28)));
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        Widget card(WishItem item, {required bool fill}) {
          return ItemCard(
            item: item,
            proxyUrl: api.sharedImageProxy(widget.token, item),
            busy: _busyId == item.id,
            fillHeight: fill,
            readOnly: true,
            onRefresh: () {},
            onEdit: () {},
            onOpen: () => _open(item),
            onDelete: () {},
            onReserve: () => _reserve(item),
            onUnreserve: item.reservedByMe ? () => _unreserve(item) : null,
          );
        }
        if (categories.isNotEmpty) {
          return GroupedItems(categories: categories, items: items, wide: wide, cardBuilder: (item, fill) => card(item, fill: fill));
        }
        if (!wide) {
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) => card(items[index], fill: false),
          );
        }
        return GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 380, mainAxisExtent: 500, crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemBuilder: (context, index) => card(items[index], fill: true),
        );
      },
    );
  }
}
