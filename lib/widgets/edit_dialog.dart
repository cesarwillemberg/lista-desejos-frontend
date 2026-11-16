import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';

Future<WishItem?> showEditDialog(BuildContext context, {required QueroApi api, required WishItem item}) {
  return showDialog<WishItem>(
    context: context,
    builder: (context) => _EditDialog(api: api, item: item),
  );
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.api, required this.item});

  final QueroApi api;
  final WishItem item;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late String _currency;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _image = TextEditingController(text: widget.item.imageUrl ?? '');
    _price = TextEditingController(text: widget.item.price == null ? '' : _priceField(widget.item.price!));
    final current = (widget.item.currency ?? 'BRL').toUpperCase();
    _currency = _currencies.contains(current) ? current : 'BRL';
  }

  @override
  void dispose() {
    _name.dispose();
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
        imageUrl: image,
        clearImage: image.isEmpty,
        price: price,
        clearPrice: priceText.isEmpty,
        currency: _currency,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Editar item', style: fraunces(26)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nome', style: TextStyle(fontSize: 13, color: QueroColors.muted)),
              const SizedBox(height: 6),
              TextField(controller: _name, decoration: _field()),
              const SizedBox(height: 14),
              const Text('URL da imagem', style: TextStyle(fontSize: 13, color: QueroColors.muted)),
              const SizedBox(height: 6),
              TextField(controller: _image, decoration: _field(hint: 'https://')),
              const SizedBox(height: 14),
              const Text('Preço', style: TextStyle(fontSize: 13, color: QueroColors.muted)),
              const SizedBox(height: 6),
              TextField(controller: _price, keyboardType: TextInputType.number, decoration: _field(hint: '1.299,90')),
              const SizedBox(height: 14),
              const Text('Moeda', style: TextStyle(fontSize: 13, color: QueroColors.muted)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: _currency,
                isExpanded: true,
                items: [for (final code in _currencies) DropdownMenuItem(value: code, child: Text(code))],
                onChanged: _busy ? null : (value) => setState(() => _currency = value ?? _currency),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: QueroColors.danger, height: 1.35)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
          child: Text(_busy ? 'Salvando…' : 'Salvar'),
        ),
      ],
    );
  }

  InputDecoration _field({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: QueroColors.line)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: QueroColors.line),
      ),
    );
  }
}

const _currencies = ['BRL', 'USD', 'EUR', 'GBP'];

String _priceField(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
