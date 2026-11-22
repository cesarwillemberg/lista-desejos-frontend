import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'theme.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'A senha precisa ter pelo menos 8 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    try {
      final account = _creating
          ? await session.api.register(email: email, password: password)
          : await session.api.login(email: email, password: password);
      await session.enter(account);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= WishlyBreak.lg;
        final form = _form(onDark: false);
        if (!wide) {
          return Scaffold(
            backgroundColor: context.wishlyPaper,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(WishlySpace.s6, WishlySpace.s10, WishlySpace.s6, WishlySpace.s6),
                children: [
                  Text('Wishly', style: fraunces(WishlyText.xl5, style: FontStyle.italic)),
                  const SizedBox(height: WishlySpace.s2),
                  Text('Entre para guardar suas listas neste aparelho.', style: TextStyle(color: context.wishlyMuted, height: WishlyText.body)),
                  const SizedBox(height: WishlySpace.s8),
                  form,
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: context.wishlyPaper,
          body: Row(
            children: [
              Expanded(
                child: ColoredBox(
                  color: QueroColors.ink,
                  child: Padding(
                    padding: const EdgeInsets.all(WishlySpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wishly', style: fraunces(WishlyText.xl6, style: FontStyle.italic, color: QueroColors.cream)),
                        const SizedBox(height: WishlySpace.s3),
                        const Text(
                          'Suas listas de desejos, com foto e preço da loja. Compartilhe um link para ninguém comprar o mesmo presente.',
                          style: TextStyle(color: WishlyTokens.onInk, fontSize: WishlyText.lg, height: WishlyText.body),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: Center(child: SizedBox(width: WishlySize.field, child: form))),
            ],
          ),
        );
      },
    );
  }

  Widget _form({required bool onDark}) {
    final label = onDark ? WishlyTokens.onInkLabel : context.wishlyMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_creating ? 'CRIAR CONTA' : 'ENTRAR', style: TextStyle(color: label, letterSpacing: WishlyText.tracking, fontWeight: FontWeight.w700, fontSize: WishlyText.xs)),
        const SizedBox(height: WishlySpace.s4),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _decoration('E-mail', onDark),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: WishlySpace.s3),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: _creating ? const [AutofillHints.newPassword] : const [AutofillHints.password],
          decoration: _decoration('Senha', onDark),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: WishlySpace.s3),
          Text(_error!, style: TextStyle(color: onDark ? WishlyColor.onInkDanger : context.wishlyDanger, height: WishlyText.body)),
        ],
        const SizedBox(height: WishlySpace.s4),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: QueroColors.accent,
            foregroundColor: context.wishlyOnAccent,
            minimumSize: const Size.fromHeight(WishlySpace.s12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.lg)),
          ),
          child: Text(_busy ? 'Aguarde…' : (_creating ? 'Criar conta' : 'Entrar'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: WishlySpace.s2),
        TextButton(
          onPressed: _busy ? null : () => setState(() { _creating = !_creating; _error = null; }),
          child: Text(_creating ? 'Já tem conta? Entrar' : 'Não tem conta? Criar conta'),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint, bool onDark) {
    if (!onDark) return wishlyField(context, hint: hint);
    final radius = BorderRadius.circular(WishlyRadius.lg);
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: WishlyColor.onInkHint, fontSize: WishlyText.base),
      filled: true,
      fillColor: WishlyColor.inkSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4, vertical: WishlySpace.s3),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: WishlyColor.transparent)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: WishlyColor.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: WishlyColor.accent, width: WishlySize.ring)),
    );
  }
}
