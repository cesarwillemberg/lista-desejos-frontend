import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';
import 'models.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/member_avatars.dart';

class MembersDialog extends StatefulWidget {
  const MembersDialog({super.key, required this.api, required this.list});

  final QueroApi api;
  final WishList list;

  @override
  State<MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<MembersDialog> {
  late WishList _list;
  final _email = TextEditingController();
  String _inviteRole = 'editor';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshList() async {
    final snapshot = await widget.api.listItems(_list.id);
    if (!mounted || snapshot.list == null) return;
    setState(() => _list = snapshot.list!);
  }

  @override
  Widget build(BuildContext context) {
    final userId = SessionScope.of(context).user?.id;
    return Dialog(
      backgroundColor: context.wishlyPaper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WishlyRadius.xl2)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WishlySize.dialog, maxHeight: WishlySize.dialogTall),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WishlySpace.s6, WishlySpace.s5, WishlySpace.s6, WishlySpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Membros', style: fraunces(WishlyText.xl3))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text('Colaborar em ${_list.name}', style: TextStyle(color: context.wishlyMuted)),
              const SizedBox(height: WishlySpace.s3),
              MemberAvatars(members: _list.members),
              const SizedBox(height: WishlySpace.s2),
              Expanded(
                child: ListView(
                  children: [
                    for (final member in _list.members) _memberTile(member, userId),
                    if (_list.isOwner) ...[
                      const SizedBox(height: WishlySpace.s2),
                      Text('Convidar', style: fraunces(WishlyText.xl)),
                      const SizedBox(height: WishlySpace.s2),
                      _inviteBlock('editor', 'Pode editar', _list.inviteEditorUrl),
                      const SizedBox(height: WishlySpace.s3),
                      _inviteBlock('viewer', 'Só pode ver', _list.inviteViewerUrl),
                      const SizedBox(height: WishlySpace.s4),
                      const Text('Por e-mail', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: WishlySpace.s2),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(hintText: 'pessoa@email.com'),
                      ),
                      const SizedBox(height: WishlySpace.s2),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'editor', label: Text('Pode editar')),
                          ButtonSegment(value: 'viewer', label: Text('Só pode ver')),
                        ],
                        selected: {_inviteRole},
                        onSelectionChanged: (value) => setState(() => _inviteRole = value.first),
                      ),
                      const SizedBox(height: WishlySpace.s2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _busy ? null : _addEmail,
                          style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
                          child: const Text('Adicionar'),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: WishlySpace.s2),
                      Text(_error!, style: TextStyle(color: context.wishlyDanger)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberTile(ListMember member, String? userId) {
    final mine = userId != null && member.userId == userId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WishlySpace.s2),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: QueroColors.ink,
            child: Text(member.initials, style: const TextStyle(color: WishlyColor.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: WishlySpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(roleLabel(member.role), style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.xs)),
              ],
            ),
          ),
          if (_list.isOwner && member.role != 'owner')
            PopupMenuButton<String>(
              onSelected: (value) => _onMemberAction(member, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'editor', child: Text('Pode editar')),
                PopupMenuItem(value: 'viewer', child: Text('Só pode ver')),
                PopupMenuItem(value: 'remove', child: Text('Remover')),
              ],
            )
          else if (mine && !_list.isOwner)
            TextButton(onPressed: _busy ? null : _leave, child: Text('Sair', style: TextStyle(color: context.wishlyDanger))),
        ],
      ),
    );
  }

  Widget _inviteBlock(String role, String title, String? url) {
    return DecoratedBox(
      decoration: BoxDecoration(color: context.wishlyWhite, borderRadius: BorderRadius.circular(WishlyRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(WishlySpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: WishlySpace.s1),
            Text(url ?? 'Link desativado', style: TextStyle(color: context.wishlyMuted, fontSize: WishlyText.sm)),
            Wrap(
              spacing: WishlySpace.s1,
              children: [
                if (url == null)
                  TextButton(onPressed: _busy ? null : () => _setLink(role, create: true), child: const Text('Criar link'))
                else ...[
                  TextButton(onPressed: () => _copy(url), child: const Text('Copiar')),
                  TextButton(onPressed: () => _share(url), child: const Text('Enviar')),
                  TextButton(onPressed: _busy ? null : () => _setLink(role, regenerate: true), child: const Text('Gerar novo')),
                  TextButton(onPressed: _busy ? null : () => _setLink(role), child: const Text('Desativar')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Informe um e-mail.');
      return;
    }
    await _run(() async {
      await widget.api.inviteByEmail(_list.id, email, _inviteRole);
      _email.clear();
      await _refreshList();
    });
  }

  Future<void> _onMemberAction(ListMember member, String value) async {
    await _run(() async {
      if (value == 'remove') {
        await widget.api.removeMember(_list.id, member.userId);
      } else {
        await widget.api.changeMemberRole(_list.id, member.userId, value);
      }
      await _refreshList();
    });
  }

  Future<void> _setLink(String role, {bool create = false, bool regenerate = false}) async {
    await _run(() async {
      final WishList updated;
      if (regenerate) {
        updated = await widget.api.regenerateInvite(_list.id, role);
      } else if (create) {
        updated = await widget.api.openInvite(_list.id, role);
      } else {
        updated = await widget.api.disableInvite(_list.id, role);
      }
      if (mounted) setState(() => _list = updated);
    });
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado.')));
  }

  Future<void> _share(String url) async {
    try {
      await SharePlus.instance.share(ShareParams(text: url, subject: _list.name));
    } catch (_) {
      await _copy(url);
    }
  }

  Future<void> _leave() async {
    await _run(() async {
      await widget.api.leaveList(_list.id);
      if (mounted) Navigator.pop(context, true);
    });
  }
}
