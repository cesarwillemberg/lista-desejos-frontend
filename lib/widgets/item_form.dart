import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';

const _currencies = ['BRL', 'USD', 'EUR', 'GBP'];

Future<WishItem?> showItemEditor(
  BuildContext context, {
  required QueroApi api,
  required String listId,
  WishItem? item,
  List<WishCategory> categories = const [],
  String? initialCategoryId,
  String? initialUrl,
  String? initialName,
  ValueChanged<WishCategory>? onCategoryCreated,
}) {
  final wide = MediaQuery.sizeOf(context).width >= WishlyBreak.md;
  Widget buildForm(BuildContext sheetContext) {
    return ItemForm(
      api: api,
      listId: listId,
      item: item,
      categories: categories,
      initialCategoryId: initialCategoryId,
      initialUrl: initialUrl,
      initialName: initialName,
      onCategoryCreated: onCategoryCreated,
      presentedAsSheet: !wide,
      onSaved: (saved) => Navigator.of(sheetContext).pop(saved),
    );
  }

  if (wide) {
    return showDialog<WishItem>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: WishlyColor.transparent,
        insetPadding: const EdgeInsets.all(WishlySpace.s6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: WishlySize.sheet, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: buildForm(context),
        ),
      ),
    );
  }
  return showModalBottomSheet<WishItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WishlyColor.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: buildForm(context),
      ),
    ),
  );
}

class ItemForm extends StatefulWidget {
  const ItemForm({
    super.key,
    required this.api,
    required this.listId,
    required this.onSaved,
    this.item,
    this.categories = const [],
    this.initialCategoryId,
    this.initialUrl,
    this.initialName,
    this.onCategoryCreated,
    this.presentedAsSheet = false,
  });

  final QueroApi api;
  final String listId;
  final ValueChanged<WishItem> onSaved;
  final WishItem? item;
  final List<WishCategory> categories;
  final String? initialCategoryId;
  final String? initialUrl;
  final String? initialName;
  final ValueChanged<WishCategory>? onCategoryCreated;
  final bool presentedAsSheet;

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _note;
  late final TextEditingController _color;
  late final TextEditingController _size;
  late final TextEditingController _voltage;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _image;
  late String _priority;
  late String _currency;
  late bool _purchased;
  late bool _more;
  String? _categoryId;
  late List<WishCategory> _categories;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? widget.initialName ?? '');
    _url = TextEditingController(text: item?.url ?? widget.initialUrl ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _color = TextEditingController(text: item?.colorName ?? '');
    _size = TextEditingController(text: item?.sizeLabel ?? '');
    _voltage = TextEditingController(text: item?.voltage ?? '');
    _quantity = TextEditingController(text: item?.quantity == null ? '' : '${item!.quantity}');
    _price = TextEditingController(text: item?.price == null ? '' : _priceField(item!.price!));
    _image = TextEditingController(text: item?.imageUrl ?? '');
    _priority = item?.priority ?? 'quero';
    final currency = (item?.currency ?? 'BRL').toUpperCase();
    _currency = _currencies.contains(currency) ? currency : 'BRL';
    _purchased = item?.purchased ?? false;
    _categoryId = item?.categoryId ?? widget.initialCategoryId;
    _categories = [...widget.categories];
    _more = item != null;
  }

  @override
  void dispose() {
    for (final controller in [_name, _url, _note, _color, _size, _voltage, _quantity, _price, _image]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'O link do produto precisa começar com http:// ou https://.');
      return;
    }
    final name = _name.text.trim();
    if (_editing && name.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }
    final image = _image.text.trim();
    if (image.isNotEmpty && !image.startsWith('http://') && !image.startsWith('https://')) {
      setState(() => _error = 'A imagem precisa ser um link http ou https.');
      return;
    }
    final quantityText = _quantity.text.trim();
    int? quantity;
    if (quantityText.isNotEmpty) {
      quantity = int.tryParse(quantityText);
      if (quantity == null || quantity < 1 || quantity > 999) {
        setState(() => _error = 'A quantidade precisa ficar entre 1 e 999.');
        return;
      }
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
      final WishItem saved;
      if (widget.item == null) {
        saved = await widget.api.createItem(
          listId: widget.listId,
          name: name.isEmpty ? null : name,
          url: url,
          categoryId: _categoryId,
          priority: _priority,
          note: _note.text,
          colorName: _color.text,
          sizeLabel: _size.text,
          voltage: _voltage.text,
          quantity: quantity,
          price: price,
          currency: price == null ? null : _currency,
          imageUrl: image,
        );
      } else {
        saved = await widget.api.updateItem(
          widget.item!.id,
          name: name,
          url: url,
          note: _note.text.trim(),
          priority: _priority,
          colorName: _color.text.trim(),
          sizeLabel: _size.text.trim(),
          voltage: _voltage.text.trim(),
          quantity: quantity,
          setQuantity: true,
          imageUrl: image,
          clearImage: image.isEmpty,
          price: price,
          clearPrice: priceText.isEmpty,
          currency: _currency,
          setCategory: true,
          categoryId: _categoryId,
          purchased: _purchased,
        );
      }
      if (!mounted) return;
      widget.onSaved(saved);
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
    final ink = context.wishlyInk;
    final label = TextStyle(color: ink, fontSize: WishlyText.sm, fontWeight: FontWeight.w700);
    final value = TextStyle(color: ink, fontSize: WishlyText.base);
    final radius = widget.presentedAsSheet
        ? const BorderRadius.vertical(top: Radius.circular(WishlyRadius.xl2))
        : BorderRadius.circular(WishlyRadius.xl2);
    return Material(
      color: context.wishlyCream,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(WishlySpace.s5, WishlySpace.s4, WishlySpace.s5, WishlySpace.s5),
        children: [
          if (widget.presentedAsSheet)
            Center(
              child: Container(
                width: WishlySpace.s10,
                height: WishlySpace.s1,
                margin: const EdgeInsets.only(bottom: WishlySpace.s3),
                decoration: BoxDecoration(color: context.wishlyLine, borderRadius: BorderRadius.circular(WishlyRadius.full)),
              ),
            ),
          Text(_editing ? 'Editar item' : 'Novo item', style: fraunces(WishlyText.xl2, color: ink)),
          _label('Nome (opcional)', label),
          _field(controller: _name, style: value, hint: 'Se vazio, usamos o nome da página'),
          _label('Link do produto', label),
          _field(controller: _url, style: value, hint: 'https://', type: TextInputType.url, action: TextInputAction.next),
          _label('Categoria', label),
          _menu<String>(
            value: _categoryId ?? '',
            entries: [
              (value: '', label: 'Sem categoria'),
              for (final category in _categories) (value: category.id, label: category.name),
              if (widget.onCategoryCreated != null) (value: '__new__', label: 'Nova categoria…'),
            ],
            onChanged: (value) async {
              if (value == '__new__') {
                final created = await _askCategoryName(context);
                if (created == null || created.isEmpty || !mounted) return;
                final category = await widget.api.createCategory(widget.listId, created);
                widget.onCategoryCreated?.call(category);
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
          _label('Prioridade', label),
          _menu<String>(
            value: _priority,
            entries: const [
              (value: 'muito', label: 'Quero muito'),
              (value: 'quero', label: 'Quero'),
              (value: 'talvez', label: 'Talvez'),
            ],
            onChanged: (value) => setState(() => _priority = value ?? _priority),
          ),
          _label('Nota', label),
          _field(controller: _note, style: value, hint: 'Um recado para quem for comprar', lines: 3),
          _label('Detalhes rápidos', label),
          _field(controller: _color, style: value, hint: 'Cor'),
          const SizedBox(height: WishlySpace.s2),
          _field(controller: _size, style: value, hint: 'Tamanho'),
          const SizedBox(height: WishlySpace.s2),
          _field(controller: _voltage, style: value, hint: 'Voltagem'),
          const SizedBox(height: WishlySpace.s2),
          _field(controller: _quantity, style: value, hint: 'Quantidade', type: TextInputType.number),
          const SizedBox(height: WishlySpace.s3),
          TextButton.icon(
            onPressed: _busy ? null : () => setState(() => _more = !_more),
            icon: Icon(_more ? Icons.expand_less : Icons.expand_more, color: ink),
            label: Text('Mais opções', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
          ),
          if (_more) ...[
            _label('Preço', label),
            _field(controller: _price, style: value, hint: '1.299,90', type: TextInputType.number),
            _label('Moeda', label),
            _menu<String>(
              value: _currency,
              entries: [for (final code in _currencies) (value: code, label: code)],
              onChanged: (value) => setState(() => _currency = value ?? _currency),
            ),
            _label('URL da imagem', label),
            _field(controller: _image, style: value, hint: 'https://', type: TextInputType.url),
          ],
          if (_editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Comprado', style: label),
              subtitle: Text(_purchased ? 'Marcado como comprado' : 'Ainda não comprei', style: TextStyle(color: context.wishlyMuted)),
              value: _purchased,
              activeThumbColor: context.wishlyOnForest,
              activeTrackColor: context.wishlyForest,
              onChanged: _busy ? null : (value) => setState(() => _purchased = value),
            ),
          if (_error != null) ...[
            const SizedBox(height: WishlySpace.s3),
            Text(_error!, style: TextStyle(color: context.wishlyDanger, height: WishlyText.body)),
          ],
          const SizedBox(height: WishlySpace.s4),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: WishlyColor.accent,
              foregroundColor: context.wishlyOnAccent,
              minimumSize: const Size.fromHeight(WishlySpace.s12),
            ),
            child: Text(_busy ? 'Salvando…' : (_editing ? 'Salvar' : 'Adicionar à lista'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(top: WishlySpace.s4, bottom: WishlySpace.s2),
      child: Text(text, style: style),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required TextStyle style,
    String? hint,
    TextInputType? type,
    TextInputAction? action,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: type,
      textInputAction: action,
      minLines: lines == 1 ? 1 : lines,
      maxLines: lines,
      style: style,
      cursorColor: WishlyColor.accent,
      decoration: wishlyField(context, hint: hint),
    );
  }

  Widget _menu<T extends String>({
    required T value,
    required List<({T value, String label})> entries,
    required ValueChanged<T?> onChanged,
  }) {
    final ink = context.wishlyInk;
    final selected = entries.any((entry) => entry.value == value) ? value : null;
    return InputDecorator(
      decoration: wishlyField(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          dropdownColor: context.wishlyCream,
          iconEnabledColor: ink,
          style: TextStyle(color: ink, fontSize: WishlyText.base, fontFamily: 'Outfit'),
          items: [
            for (final entry in entries)
              DropdownMenuItem(value: entry.value, child: Text(entry.label, style: TextStyle(color: ink, fontSize: WishlyText.base))),
          ],
          onChanged: _busy ? null : onChanged,
        ),
      ),
    );
  }
}

String _priceField(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

Future<String?> _askCategoryName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.wishlyCream,
      title: Text('Nova categoria', style: fraunces(WishlyText.xl2)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: context.wishlyInk, fontSize: WishlyText.base),
        cursorColor: WishlyColor.accent,
        decoration: wishlyField(context, hint: 'Ex.: Cozinha'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
          child: const Text('Criar'),
        ),
      ],
    ),
  );
}
