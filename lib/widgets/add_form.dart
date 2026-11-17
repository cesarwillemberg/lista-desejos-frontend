import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

class AddPanel extends StatefulWidget {
  const AddPanel({
    super.key,
    required this.api,
    required this.listId,
    required this.onCreated,
    this.categories = const [],
    this.onCategoryCreated,
    this.onDark = false,
  });

  final QueroApi api;
  final String listId;
  final List<WishCategory> categories;
  final ValueChanged<WishCategory>? onCategoryCreated;
  final ValueChanged<WishItem> onCreated;
  final bool onDark;

  @override
  State<AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends State<AddPanel> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  String? _categoryId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'Cole um link que comece com http:// ou https://.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await widget.api.createItem(listId: widget.listId, name: name, url: url, categoryId: _categoryId);
      if (!mounted) return;
      _name.clear();
      _url.clear();
      setState(() {
        _busy = false;
        _categoryId = null;
      });
      widget.onCreated(item);
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
    return AddForm(
      name: _name,
      url: _url,
      busy: _busy,
      error: _error,
      onDark: widget.onDark,
      onSubmit: _submit,
      categories: widget.categories,
      categoryId: _categoryId,
      onCategory: (id) => setState(() => _categoryId = id),
      onCreateCategory: widget.onCategoryCreated == null
          ? null
          : (name) async {
              final created = await widget.api.createCategory(widget.listId, name);
              widget.onCategoryCreated!(created);
              if (mounted) setState(() => _categoryId = created.id);
            },
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

class AddForm extends StatelessWidget {
  const AddForm({
    super.key,
    required this.name,
    required this.url,
    required this.busy,
    required this.onSubmit,
    this.error,
    this.onDark = false,
    this.categories = const [],
    this.categoryId,
    this.onCategory,
    this.onCreateCategory,
  });

  final TextEditingController name;
  final TextEditingController url;
  final bool busy;
  final VoidCallback onSubmit;
  final String? error;
  final bool onDark;
  final List<WishCategory> categories;
  final String? categoryId;
  final ValueChanged<String?>? onCategory;
  final Future<void> Function(String name)? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? WishlyTokens.onInkLabel : QueroColors.muted;
    final fill = onDark ? QueroColors.inkSoft : WishlyColor.white;
    final text = onDark ? QueroColors.cream : QueroColors.ink;
    final hint = onDark ? WishlyTokens.onInkHint : WishlyTokens.muted;
    final border = onDark ? WishlyColor.transparent : QueroColors.line;

    InputDecoration decoration(String hintText) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: hint, fontSize: WishlyText.base),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4, vertical: WishlySpace.s3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(WishlyRadius.lg), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WishlyRadius.lg),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WishlyRadius.lg),
          borderSide: const BorderSide(color: QueroColors.accent, width: WishlySize.ring),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('NOVO ITEM', style: TextStyle(color: labelColor, fontSize: WishlyText.xs, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w600)),
        const SizedBox(height: WishlySpace.s4),
        Text('Nome', style: TextStyle(color: labelColor, fontSize: WishlyText.sm)),
        const SizedBox(height: WishlySpace.s2),
        TextField(
          controller: name,
          enabled: !busy,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: text, fontSize: WishlyText.base),
          cursorColor: QueroColors.accent,
          decoration: decoration('Ex.: Kindle Paperwhite'),
        ),
        const SizedBox(height: WishlySpace.s4),
        Text('Link do produto', style: TextStyle(color: labelColor, fontSize: WishlyText.sm)),
        const SizedBox(height: WishlySpace.s2),
        TextField(
          controller: url,
          enabled: !busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          style: TextStyle(color: text, fontSize: WishlyText.base),
          cursorColor: QueroColors.accent,
          decoration: decoration('https://'),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: WishlySpace.s4),
          Text('Categoria', style: TextStyle(color: labelColor, fontSize: WishlyText.sm)),
          const SizedBox(height: WishlySpace.s2),
          DropdownButton<String>(
            value: categoryId ?? '',
            isExpanded: true,
            dropdownColor: onDark ? QueroColors.inkSoft : WishlyColor.white,
            style: TextStyle(color: text, fontSize: WishlyText.base),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem categoria')),
              for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
              const DropdownMenuItem(value: '__new__', child: Text('Nova categoria…')),
            ],
            onChanged: busy
                ? null
                : (value) async {
                    if (value == '__new__') {
                      final created = await _askCategoryName(context);
                      if (created != null && created.isNotEmpty) await onCreateCategory?.call(created);
                      return;
                    }
                    onCategory?.call(value == null || value.isEmpty ? null : value);
                  },
          ),
        ],
        const SizedBox(height: WishlySpace.s2),
        Text(
          'A gente abre a página da loja e traz a foto e o preço.',
          style: TextStyle(color: labelColor, fontSize: WishlyText.sm, height: WishlyText.body),
        ),
        if (error != null) ...[
          const SizedBox(height: WishlySpace.s3),
          Text(
            error!,
            style: TextStyle(color: onDark ? WishlyTokens.onInkDanger : QueroColors.danger, fontSize: WishlyText.sm, height: WishlyText.body),
          ),
        ],
        const SizedBox(height: WishlySpace.s4),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: QueroColors.accent,
            disabledBackgroundColor: QueroColors.accent.withValues(alpha: WishlyOpacity.disabled),
            foregroundColor: WishlyColor.white,
            minimumSize: const Size.fromHeight(WishlySpace.s12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.lg)),
          ),
          child: busy
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: WishlyIcon.sm, height: WishlyIcon.sm, child: CircularProgressIndicator(strokeWidth: WishlySize.spinner, color: WishlyColor.white)),
                    SizedBox(width: WishlySpace.s2),
                    Text('Buscando foto e preço…', style: TextStyle(fontWeight: FontWeight.w600, fontSize: WishlyText.base)),
                  ],
                )
              : const Text('Adicionar à lista', style: TextStyle(fontWeight: FontWeight.w600, fontSize: WishlyText.base)),
        ),
      ],
    );
  }
}
