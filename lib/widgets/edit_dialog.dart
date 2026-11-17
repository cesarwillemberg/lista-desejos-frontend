import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';

Future<WishItem?> showEditDialog(
  BuildContext context, {
  required QueroApi api,
  required WishItem item,
  List<WishCategory> categories = const [],
  Future<WishCategory> Function(String name)? onCreateCategory,
}) {
  return showDialog<WishItem>(
    context: context,
    builder: (context) => _EditDialog(api: api, item: item, categories: categories, onCreateCategory: onCreateCategory),
  );
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.api, required this.item, this.categories = const [], this.onCreateCategory});

  final QueroApi api;
  final WishItem item;
  final List<WishCategory> categories;
  final Future<WishCategory> Function(String name)? onCreateCategory;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late String _currency;
  String? _categoryId;
  late bool _purchased;
  late List<WishCategory> _categories;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _url = TextEditingController(text: widget.item.url);
    _image = TextEditingController(text: widget.item.imageUrl ?? '');
    _price = TextEditingController(text: widget.item.price == null ? '' : _priceField(widget.item.price!));
    final current = (widget.item.currency ?? 'BRL').toUpperCase();
    _currency = _currencies.contains(current) ? current : 'BRL';
    _categories = widget.categories;
    _categoryId = widget.item.categoryId;
    _purchased = widget.item.purchased;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _image.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }
    final url = _url.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'O link do produto precisa começar com http:// ou https://.');
      return;
    }
    final image = _image.text.trim();
    if (image.isNotEmpty && !image.startsWith('http://') && !image.startsWith('https://')) {
      setState(() => _error = 'A imagem precisa ser um link http ou https.');
      return;
    }
    final priceText = _price.text.trim();
    double? price;
    if (priceText.isNotEmpty) {
      price = parseUserPrice(priceText);
      if (price == null) {
        setState(() => _error = 'Não entendi esse preço. Use algo como 1.299,90.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.api.updateItem(
        widget.item.id,
        name: name,
        url: url,
        imageUrl: image,
        clearImage: image.isEmpty,
        price: price,
        clearPrice: priceText.isEmpty,
        currency: _currency,
        setCategory: _categories.isNotEmpty,
        categoryId: _categoryId,
        purchased: _purchased,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: QueroColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.xl2)),
      title: Text('Editar item', style: fraunces(WishlyText.xl2)),
      content: SizedBox(
        width: WishlySize.field,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nome', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              TextField(controller: _name, decoration: _field()),
              const SizedBox(height: WishlySpace.s4),
              const Text('Link do produto', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              TextField(controller: _url, keyboardType: TextInputType.url, decoration: _field(hint: 'https://')),
              const SizedBox(height: WishlySpace.s4),
              const Text('URL da imagem', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              TextField(controller: _image, decoration: _field(hint: 'https://')),
              const SizedBox(height: WishlySpace.s4),
              const Text('Preço', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              TextField(controller: _price, keyboardType: TextInputType.number, decoration: _field(hint: '1.299,90')),
              const SizedBox(height: WishlySpace.s2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Comprado'),
                subtitle: Text(_purchased ? 'Comprado ✓' : 'Marcar como comprado'),
                value: _purchased,
                onChanged: _busy ? null : (value) => setState(() => _purchased = value),
              ),
              const SizedBox(height: WishlySpace.s4),
              const Text('Moeda', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
              const SizedBox(height: WishlySpace.s2),
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: WishlySpace.s4),
                const Text('Categoria', style: TextStyle(fontSize: WishlyText.sm, color: QueroColors.muted)),
                const SizedBox(height: WishlySpace.s2),
                DropdownButton<String>(
                  value: _categoryId ?? '',
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sem categoria')),
                    for (final category in _categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
                    const DropdownMenuItem(value: '__new__', child: Text('Nova categoria…')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) async {
                          if (value == '__new__') {
                            final created = await _askCategoryName(context);
                            if (created == null || created.isEmpty || widget.onCreateCategory == null) return;
                            final category = await widget.onCreateCategory!(created);
                            if (!mounted) return;
                            setState(() {
                              _categories = [..._categories, category];
                              _categoryId = category.id;
                            });
                            return;
                          }
                          setState(() => _categoryId = value == null || value.isEmpty ? null : value);
                        },
                ),
              ],
              DropdownButton<String>(
                value: _currency,
                isExpanded: true,
                items: [for (final code in _currencies) DropdownMenuItem(value: code, child: Text(code))],
                onChanged: _busy ? null : (value) => setState(() => _currency = value ?? _currency),
              ),
              if (_error != null) ...[
                const SizedBox(height: WishlySpace.s3),
                Text(_error!, style: const TextStyle(color: QueroColors.danger, height: WishlyText.body)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
          child: Text(_busy ? 'Salvando…' : 'Salvar'),
        ),
      ],
    );
  }

  InputDecoration _field({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: WishlyColor.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: WishlySpace.s3, vertical: WishlySpace.s3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(WishlyRadius.lg), borderSide: const BorderSide(color: QueroColors.line)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WishlyRadius.lg),
        borderSide: const BorderSide(color: QueroColors.line),
      ),
    );
  }
}

Future<String?> _askCategoryName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: QueroColors.cream,
      title: Text('Nova categoria', style: fraunces(WishlyText.xl2)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Cozinha')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: WishlyColor.white),
          child: const Text('Criar'),
        ),
      ],
    ),
  );
}

const _currencies = ['BRL', 'USD', 'EUR', 'GBP'];

String _priceField(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
