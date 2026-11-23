import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/avatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _emailPassword = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _ready = false;
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final user = SessionScope.of(context).user;
    _name.text = user?.displayName ?? '';
    _email.text = user?.email ?? '';
    _ready = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emailPassword.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      final typed = _name.text.trim();
      final account = await session.api.updateProfile(displayName: typed, clearName: typed.isEmpty);
      await session.applyAccount(account);
      _toast('Nome atualizado.');
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEmail() async {
    final session = SessionScope.of(context);
    if (_emailPassword.text.isEmpty) {
      _toast('Informe a senha atual para trocar o e-mail.');
      return;
    }
    setState(() => _busy = true);
    try {
      final account = await session.api.changeEmail(email: _email.text.trim(), password: _emailPassword.text);
      await session.applyAccount(account, token: session.api.token);
      _emailPassword.clear();
      _toast('E-mail atualizado.');
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    if (_newPassword.text != _confirmPassword.text) {
      _toast('A confirmação não é igual à nova senha.');
      return;
    }
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      final account = await session.api.changePassword(currentPassword: _currentPassword.text, newPassword: _newPassword.text);
      await session.applyAccount(account, token: session.api.token);
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _toast('Senha atualizada. Este aparelho continua conectado.');
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    if (picked == null || !mounted) return;
    final raw = await picked.readAsBytes();
    if (!mounted) return;
    final jpeg = _squareJpeg(raw);
    if (jpeg == null) {
      _toast('Não consegui ler essa imagem.');
      return;
    }
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      final account = await session.api.uploadAvatar(jpeg);
      await session.applyAccount(account);
      _toast('Foto atualizada.');
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      final account = await session.api.deleteAvatar();
      await session.applyAccount(account);
      _toast('Foto removida.');
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await SessionScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.user;
    final wide = MediaQuery.sizeOf(context).width >= WishlyBreak.md;
    return Scaffold(
      backgroundColor: context.wishlyPaper,
      appBar: AppBar(
        backgroundColor: context.wishlyPaper,
        foregroundColor: context.wishlyInk,
        title: Text('Configurações', style: fraunces(WishlyText.xl2, color: context.wishlyInk)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? WishlySpace.s16 : WishlySpace.s4, WishlySpace.s4, wide ? WishlySpace.s16 : WishlySpace.s4, WishlySpace.s12),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('Perfil'),
                  Row(
                    children: [
                      WishlyAvatar(
                        label: user?.name ?? '?',
                        userId: user?.id,
                        hasAvatar: user?.hasAvatar ?? false,
                        version: user?.avatarAt,
                        radius: 36,
                        api: session.api,
                      ),
                      const SizedBox(width: WishlySpace.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(onPressed: _busy ? null : _pickPhoto, child: const Text('Escolher foto')),
                            if (user?.hasAvatar == true)
                              TextButton(onPressed: _busy ? null : _removePhoto, child: const Text('Remover foto')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WishlySpace.s3),
                  Text('Nome', style: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w700)),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _name, enabled: !_busy, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'Como você quer ser chamado')),
                  const SizedBox(height: WishlySpace.s2),
                  Text(
                    'Esse nome aparece em “adicionado por”, na lista de membros e quando você reserva um item. Sem nome, usamos a parte do e-mail antes do @.',
                    style: TextStyle(color: context.wishlyMuted, height: WishlyText.body),
                  ),
                  const SizedBox(height: WishlySpace.s3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _busy ? null : _saveName, child: const Text('Salvar nome')),
                  ),
                  _section('Conta'),
                  Text('E-mail', style: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w700)),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _email, enabled: !_busy, keyboardType: TextInputType.emailAddress, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'voce@email.com')),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _emailPassword, enabled: !_busy, obscureText: true, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'Senha atual')),
                  const SizedBox(height: WishlySpace.s3),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _busy ? null : _saveEmail, child: const Text('Alterar e-mail'))),
                  const SizedBox(height: WishlySpace.s5),
                  Text('Senha', style: TextStyle(color: context.wishlyInk, fontWeight: FontWeight.w700)),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _currentPassword, enabled: !_busy, obscureText: true, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'Senha atual')),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _newPassword, enabled: !_busy, obscureText: true, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'Nova senha')),
                  const SizedBox(height: WishlySpace.s2),
                  TextField(controller: _confirmPassword, enabled: !_busy, obscureText: true, style: TextStyle(color: context.wishlyInk), cursorColor: WishlyColor.accent, decoration: wishlyField(context, hint: 'Confirmar nova senha')),
                  const SizedBox(height: WishlySpace.s2),
                  Text('Mínimo de 8 caracteres. Os outros aparelhos vão precisar entrar de novo.', style: TextStyle(color: context.wishlyMuted, height: WishlyText.body)),
                  const SizedBox(height: WishlySpace.s3),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _busy ? null : _savePassword, child: const Text('Alterar senha'))),
                  _section('Aparência'),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                    ],
                    selected: {ThemeChoice.of(context).mode},
                    onSelectionChanged: (value) => ThemeChoice.of(context).onChanged(value.first),
                  ),
                  _section('Sair'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _logout, child: Text('Sair desta conta', style: TextStyle(color: context.wishlyDanger, fontWeight: FontWeight.w700))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: WishlySpace.s6, bottom: WishlySpace.s3),
      child: Text(title, style: fraunces(WishlyText.xl, color: context.wishlyInk)),
    );
  }
}

Uint8List? _squareJpeg(Uint8List bytes) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) return null;
  final square = im.copyResizeCropSquare(decoded, size: 512);
  var quality = 82;
  var jpg = im.encodeJpg(square, quality: quality);
  while (jpg.length > 200 * 1024 && quality > 40) {
    quality -= 10;
    jpg = im.encodeJpg(square, quality: quality);
  }
  return Uint8List.fromList(jpg);
}
