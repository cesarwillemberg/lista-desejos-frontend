import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'auth_page.dart';
import 'bootstrap.dart';
import 'home_page.dart';
import 'invite_page.dart';
import 'links.dart';
import 'lists_page.dart';
import 'session.dart';
import 'share_in_page.dart';
import 'shared_page.dart';
import 'theme.dart';
import 'widgets/skeleton.dart';

void main() {
  configureAppUrl();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(QueroApp(api: QueroApi(), tokens: PrefsTokenStore(), claims: PrefsClaimStore(), listenForLinks: !kIsWeb));
}

class QueroApp extends StatefulWidget {
  const QueroApp({super.key, required this.api, required this.tokens, required this.claims, this.listenForLinks = false});

  final QueroApi api;
  final TokenStore tokens;
  final ClaimStore claims;
  final bool listenForLinks;

  @override
  State<QueroApp> createState() => _QueroAppState();
}

class _QueroAppState extends State<QueroApp> {
  late final Session _session;
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _session = Session(api: widget.api, tokens: widget.tokens, claims: widget.claims);
    _session.boot();
    _loadTheme();
    if (widget.listenForLinks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listenForLinks());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedUrl());
  }

  Future<void> _listenForLinks() async {
    try {
      final appLinks = AppLinks();
      _openLink(await appLinks.getInitialLink());
      _links = appLinks.uriLinkStream.listen(_openLink);
    } catch (_) {
      // The plugin is absent in widget tests and on web.
    }
  }

  void _openSharedUrl() {
    final params = Uri.base.queryParameters;
    final shared = params['url'] ?? params['text'];
    if (shared == null || !shared.startsWith('http')) return;
    final title = Uri.encodeComponent(params['title'] ?? '');
    _navigatorKey.currentState?.pushNamed('/compartilhar?url=${Uri.encodeComponent(shared)}&title=$title');
  }

  void _openLink(Uri? uri) {
    final invite = inviteCodeFromUri(uri);
    if (invite != null) {
      _navigatorKey.currentState?.pushNamed('/c/$invite');
      return;
    }
    final code = shareCodeFromUri(uri);
    if (code == null) return;
    _navigatorKey.currentState?.pushNamed('/l/$code');
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final saved = (await SharedPreferences.getInstance()).getString('wishly_theme');
    if (!mounted) return;
    setState(() => _mode = saved == 'dark' ? ThemeMode.dark : saved == 'light' ? ThemeMode.light : ThemeMode.system);
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _mode = mode);
    await (await SharedPreferences.getInstance()).setString('wishly_theme', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }

  @override
  Widget build(BuildContext context) {
    return ThemeChoice(
      mode: _mode,
      onChanged: _setTheme,
      child: SessionScope(
      session: _session,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Wishly',
        debugShowCheckedModeBanner: false,
        theme: queroTheme(),
        darkTheme: queroTheme(brightness: Brightness.dark),
        themeMode: _mode,
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          return MaterialPageRoute(settings: settings, builder: (context) => _route(name));
        },
      ),
    ),
    );
  }
}


Widget _route(String name) {
  final path = name.split('?').first;
  if (path.startsWith('/compartilhar')) {
    final params = Uri.parse(name).queryParameters;
    final url = params['url'] ?? '';
    return _Gate(child: ShareInPage(url: url, title: params['title']));
  }
  if (path.startsWith('/c/') && path.length > 3) {
    return _Gate(child: InvitePage(code: Uri.decodeComponent(path.substring(3))));
  }
  if (path.startsWith('/l/') && path.length > 3) {
    return SharedPage(token: Uri.decodeComponent(path.substring(3)));
  }
  if (path.startsWith('/list/') && path.length > 6) {
    return _Gate(child: ListDetailPage(listId: Uri.decodeComponent(path.substring(6))));
  }
  return const _Gate(child: ListsPage());
}

class _Gate extends StatelessWidget {
  const _Gate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.ready) {
      return Scaffold(backgroundColor: context.wishlyPaper, body: const PageSkeleton());
    }
    if (session.user == null) return const AuthPage();
    return child;
  }
}
