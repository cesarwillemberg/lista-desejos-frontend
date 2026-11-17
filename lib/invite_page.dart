import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'theme.dart';

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
      backgroundColor: QueroColors.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Entrando na lista', style: fraunces(28)),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: QueroColors.ink),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _accept,
                      style: FilledButton.styleFrom(backgroundColor: QueroColors.accent, foregroundColor: Colors.white),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
