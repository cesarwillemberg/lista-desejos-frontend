import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? token) async => value = token;
}

class PrefsTokenStore implements TokenStore {
  static const _key = 'quero_token';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, token);
    }
  }
}

abstract class ClaimStore {
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> claims);
}

class MemoryClaimStore implements ClaimStore {
  Map<String, String> value = {};

  @override
  Future<Map<String, String>> read() async => value;

  @override
  Future<void> write(Map<String, String> claims) async => value = claims;
}

class PrefsClaimStore implements ClaimStore {
  static const _key = 'quero_claims';

  @override
  Future<Map<String, String>> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  @override
  Future<void> write(Map<String, String> claims) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(claims));
  }
}

class Session extends ChangeNotifier {
  Session({required this.api, required this.tokens, required this.claims});

  final QueroApi api;
  final TokenStore tokens;
  final ClaimStore claims;
  UserAccount? user;
  Map<String, String> claimMap = {};
  bool ready = false;

  String? get claimHeader {
    if (claimMap.isEmpty) return null;
    return claimMap.entries.map((entry) => '${entry.key}:${entry.value}').join(',');
  }

  Future<void> boot() async {
    claimMap = await claims.read();
    final saved = await tokens.read();
    if (saved != null && saved.isNotEmpty) {
      api.token = saved;
      try {
        user = await api.me();
      } on ApiException {
        api.token = null;
        user = null;
        await tokens.write(null);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> enter(UserAccount account) async {
    await tokens.write(api.token);
    user = account;
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    await tokens.write(null);
    notifyListeners();
  }

  Future<void> rememberClaim(String itemId, String token) async {
    claimMap = {...claimMap, itemId: token};
    await claims.write(claimMap);
    notifyListeners();
  }

  Future<void> forgetClaim(String itemId) async {
    claimMap = {...claimMap}..remove(itemId);
    await claims.write(claimMap);
    notifyListeners();
  }
}

class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({required Session session, required super.child, super.key}) : super(notifier: session);

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope ausente');
    return scope!.notifier!;
  }
}
