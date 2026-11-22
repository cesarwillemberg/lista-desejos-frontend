import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets/skeleton.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.code});

  final String code;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  String? _error;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _accept();
  }

  Future<void> _accept() async {
    setState(() => _error = null);
    try {
      final list = await SessionScope.of(context).api.acceptInvite(widget.code);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/list/${list.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.wishlyPaper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(WishlySpace.s8),
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Entrando na lista', style: fraunces(WishlyText.xl3)),
                    const SizedBox(height: WishlySpace.s4),
                    WishlySkeleton(height: WishlyText.lg, width: WishlySize.skeletonLine),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: WishlySpace.s4),
                    FilledButton(
                      onPressed: _accept,
                      style: FilledButton.styleFrom(backgroundColor: WishlyColor.accent, foregroundColor: context.wishlyOnAccent),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
