import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

class AddPanel extends StatefulWidget {
  const AddPanel({super.key, required this.api, required this.listId, required this.onCreated, this.onDark = false});

  final QueroApi api;
  final String listId;
  final ValueChanged<WishItem> onCreated;
  final bool onDark;

  @override
  State<AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends State<AddPanel> {
  final _name = TextEditingController();
  final _url = TextEditingController();
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
      final item = await widget.api.createItem(listId: widget.listId, name: name, url: url);
      if (!mounted) return;
      _name.clear();
      _url.clear();
      setState(() => _busy = false);
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
    return AddForm(name: _name, url: _url, busy: _busy, error: _error, onDark: widget.onDark, onSubmit: _submit);
  }
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
  });

  final TextEditingController name;
  final TextEditingController url;
  final bool busy;
  final VoidCallback onSubmit;
  final String? error;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? const Color(0xFFD9CFC4) : QueroColors.muted;
    final fill = onDark ? QueroColors.inkSoft : Colors.white;
    final text = onDark ? QueroColors.cream : QueroColors.ink;
    final hint = onDark ? const Color(0xFFB3A79C) : const Color(0xFFA3988C);
    final border = onDark ? Colors.transparent : QueroColors.line;

    InputDecoration decoration(String hintText) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: hint, fontSize: 15),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QueroColors.accent, width: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('NOVO ITEM', style: TextStyle(color: labelColor, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Text('Nome', style: TextStyle(color: labelColor, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: name,
          enabled: !busy,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: text, fontSize: 16),
          cursorColor: QueroColors.accent,
          decoration: decoration('Ex.: Kindle Paperwhite'),
        ),
        const SizedBox(height: 14),
        Text('Link do produto', style: TextStyle(color: labelColor, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: url,
          enabled: !busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          style: TextStyle(color: text, fontSize: 16),
          cursorColor: QueroColors.accent,
          decoration: decoration('https://'),
        ),
        const SizedBox(height: 8),
        Text(
          'A gente abre a página da loja e traz a foto e o preço.',
          style: TextStyle(color: labelColor, fontSize: 13, height: 1.35),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: onDark ? const Color(0xFFFFB4A2) : QueroColors.danger, fontSize: 13, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: QueroColors.accent,
            disabledBackgroundColor: QueroColors.accent.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text('Buscando foto e preço…', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                )
              : const Text('Adicionar à lista', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
  }
}
