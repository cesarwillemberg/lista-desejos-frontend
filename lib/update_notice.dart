import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'update.dart';

/// Compiled build id. The Pages workflow passes the commit SHA; local builds stay on `dev`.
const wishlyBuildId = String.fromEnvironment('WISHLY_BUILD', defaultValue: 'dev');

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key});

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> with WidgetsBindingObserver {
  Timer? _timer;
  var _available = false;
  var _applying = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || wishlyBuildId == 'dev') return;
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (kIsWeb && wishlyBuildId != 'dev') WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.base.resolve('version.json').replace(queryParameters: {'t': stamp});
      final response = await http.get(uri, headers: const {'cache-control': 'no-store'}).timeout(const Duration(seconds: 8));
      if (!mounted || response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      final remote = body is Map ? body['build'] as String? : null;
      if (remote != null && remote.isNotEmpty && remote != wishlyBuildId) {
        setState(() => _available = true);
      }
    } catch (_) {
      // A missing version file just means this build has nothing to compare.
    }
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    await applyAppUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return Material(
      color: WishlyColor.accent,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: _applying ? null : _apply,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WishlySpace.s4, vertical: WishlySpace.s3),
            child: Row(
              children: [
                const Icon(Icons.system_update_alt, color: WishlyColor.white, size: WishlyIcon.md),
                const SizedBox(width: WishlySpace.s3),
                const Expanded(
                  child: Text(
                    'Nova versão disponível — toque para atualizar',
                    style: TextStyle(color: WishlyColor.white, fontWeight: FontWeight.w700, height: WishlyText.body),
                  ),
                ),
                if (_applying) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WishlyColor.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
