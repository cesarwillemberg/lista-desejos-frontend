import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/item_form.dart';

class ShareInPage extends StatefulWidget {
  const ShareInPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<ShareInPage> createState() => _ShareInPageState();
}

class _ShareInPageState extends State<ShareInPage> {
  List<WishList> _lists = [];
  String? _listId;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  var _started = false;

  Future<void> _load() async {
    if (_started) return;
    _started = true;
    try {
      final lists = await SessionScope.of(context).api.lists();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _listId = lists.isEmpty ? null : lists.first.id;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listId = _listId;
    return Scaffold(
      backgroundColor: context.wishlyPaper,
      appBar: AppBar(title: Text('Adicionar da web', style: fraunces(WishlyText.xl))),
      body: ListView(
        padding: const EdgeInsets.all(WishlySpace.s4),
        children: [
          Text('No iPhone, o compartilhamento direto não abre este app. Use o atalho abaixo ou o marcador.', style: TextStyle(color: context.wishlyMuted, height: WishlyText.body)),
          const SizedBox(height: WishlySpace.s3),
          SelectableText(_bookmarklet, style: const TextStyle(fontSize: WishlyText.xs)),
          const SizedBox(height: WishlySpace.s4),
          if (_error != null) Text(_error!, style: TextStyle(color: context.wishlyDanger)),
          if (_lists.isEmpty)
            const Text('Entre e crie uma lista para guardar este link.')
          else ...[
            DropdownButton<String>(
              value: listId,
              isExpanded: true,
              dropdownColor: context.wishlyCream,
              iconEnabledColor: context.wishlyInk,
              style: TextStyle(color: context.wishlyInk, fontSize: WishlyText.base),
              items: [
                for (final list in _lists)
                  DropdownMenuItem(value: list.id, child: Text(list.name, style: TextStyle(color: context.wishlyInk))),
              ],
              onChanged: (value) => setState(() => _listId = value),
            ),
            const SizedBox(height: WishlySpace.s4),
            if (listId != null)
              ItemForm(
                api: SessionScope.of(context).api,
                listId: listId,
                initialName: widget.title,
                initialUrl: widget.url,
                onSaved: (item) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} entrou na lista.')));
                  Navigator.of(context).pushNamedAndRemoveUntil('/list/$listId', (route) => false);
                },
              ),
          ],
        ],
      ),
    );
  }
}

const _bookmarklet =
    "javascript:(function(){var u=encodeURIComponent(location.href);var t=encodeURIComponent(document.title);location.href='https://cesarwillemberg.github.io/lista-desejos-frontend/#/compartilhar?url='+u+'&title='+t;})();";
