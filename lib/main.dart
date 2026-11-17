import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'auth_page.dart';
import 'bootstrap.dart';
import 'home_page.dart';
import 'invite_page.dart';
import 'links.dart';
import 'lists_page.dart';
import 'session.dart';
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

  @override
  void initState() {
    super.initState();
    _session = Session(api: widget.api, tokens: widget.tokens, claims: widget.claims);
    _session.boot();
    if (widget.listenForLinks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listenForLinks());
    }
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

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Wishly',
        debugShowCheckedModeBanner: false,
        theme: queroTheme(),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          return MaterialPageRoute(settings: settings, builder: (context) => _route(name));
        },
      ),
    );
  }
}

Widget _route(String name) {
  final path = name.split('?').first;
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
      return const Scaffold(backgroundColor: QueroColors.paper, body: PageSkeleton());
    }
    if (session.user == null) return const AuthPage();
    return child;
  }
}
