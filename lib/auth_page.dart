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
        final wide = constraints.maxWidth >= 900;
        final form = _form(onDark: false);
        if (!wide) {
          return Scaffold(
            backgroundColor: QueroColors.paper,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                children: [
                  Text('Quero', style: fraunces(48, style: FontStyle.italic)),
                  const SizedBox(height: 8),
                  const Text('Entre para guardar suas listas neste aparelho.', style: TextStyle(color: QueroColors.muted, height: 1.4)),
                  const SizedBox(height: 28),
                  form,
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: QueroColors.paper,
          body: Row(
            children: [
              Expanded(
                child: ColoredBox(
                  color: QueroColors.ink,
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quero', style: fraunces(64, style: FontStyle.italic, color: QueroColors.cream)),
                        const SizedBox(height: 12),
                        const Text(
                          'Suas listas de desejos, com foto e preço da loja. Compartilhe um link para ninguém comprar o mesmo presente.',
                          style: TextStyle(color: Color(0xFFD7CDC2), fontSize: 18, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: Center(child: SizedBox(width: 420, child: form))),
            ],
          ),
        );
      },
    );
  }

  Widget _form({required bool onDark}) {
    final label = onDark ? const Color(0xFFD9CFC4) : QueroColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_creating ? 'CRIAR CONTA' : 'ENTRAR', style: TextStyle(color: label, letterSpacing: 1.4, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _decoration('E-mail', onDark),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: _creating ? const [AutofillHints.newPassword] : const [AutofillHints.password],
          decoration: _decoration('Senha', onDark),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: onDark ? const Color(0xFFFFB4A2) : QueroColors.danger, height: 1.35)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: QueroColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_busy ? 'Aguarde…' : (_creating ? 'Criar conta' : 'Entrar'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => setState(() { _creating = !_creating; _error = null; }),
          child: Text(_creating ? 'Já tem conta? Entrar' : 'Não tem conta? Criar conta'),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint, bool onDark) {
    final border = onDark ? Colors.transparent : QueroColors.line;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: onDark ? QueroColors.inkSoft : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: QueroColors.accent, width: 1.4)),
    );
  }
}
