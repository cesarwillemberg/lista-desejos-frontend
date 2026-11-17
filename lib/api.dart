import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class QueroApi {
  QueroApi({http.Client? client, String? root}) : _client = client ?? http.Client(), _rootOverride = root;

  final http.Client _client;
  final String? _rootOverride;
  String? token;

  String get root {
    final override = _rootOverride;
    if (override != null && override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    const defined = String.fromEnvironment('API_BASE');
    if (defined.isNotEmpty) return defined.replaceAll(RegExp(r'/+$'), '');
    if (kIsWeb) return Uri.base.origin;
    return 'http://127.0.0.1:47231';
  }

  Map<String, String> get authHeaders {
    final current = token;
    if (current == null || current.isEmpty) return const {};
    return {'authorization': 'Bearer $current'};
  }

  String imageProxy(WishItem item) {
    final version = item.updatedAt.millisecondsSinceEpoch;
    return '$root/api/items/${item.id}/image?v=$version';
  }

  String sharedImageProxy(String shareToken, WishItem item) {
    final version = item.updatedAt.millisecondsSinceEpoch;
    return '$root/api/share/$shareToken/items/${item.id}/image?v=$version';
  }

  String shareLink(String shareToken) {
    final base = Uri.base;
    final path = base.path.isEmpty ? '/' : (base.path.endsWith('/') ? base.path : '${base.path}/');
    return '${base.scheme}://${base.authority}$path#/l/$shareToken';
  }

  Future<UserAccount> register({required String email, required String password}) async {
    final response = await _send('POST', '/api/auth/register', {'email': email, 'password': password});
    return _storeSession(response);
  }

  Future<UserAccount> login({required String email, required String password}) async {
    final response = await _send('POST', '/api/auth/login', {'email': email, 'password': password});
    return _storeSession(response);
  }

  UserAccount _storeSession(http.Response response) {
    final body = _jsonMap(response);
    token = body['token'] as String;
    return UserAccount.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserAccount> me() async {
    final response = await _send('GET', '/api/auth/me');
    return UserAccount.fromJson(_jsonMap(response));
  }

  Future<List<WishList>> lists() async {
    final response = await _send('GET', '/api/lists', null, null, const Duration(seconds: 20));
    return _lists(_jsonMap(response)['lists']);
  }

  Future<WishList> createList(String name) async {
    final response = await _send('POST', '/api/lists', {'name': name});
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> renameList(String id, String name) async {
    final response = await _send('PATCH', '/api/lists/$id', {'name': name});
    return WishList.fromJson(_jsonMap(response));
  }

  Future<void> deleteList(String id) async {
    await _send('DELETE', '/api/lists/$id');
  }

  Future<WishList> shareList(String id) async {
    final response = await _send('POST', '/api/lists/$id/share');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> regenerateShare(String id) async {
    final response = await _send('POST', '/api/lists/$id/share/regenerate');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> revokeShare(String id) async {
    final response = await _send('DELETE', '/api/lists/$id/share');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishlistSnapshot> listItems(String listId) async {
    final response = await _send('GET', '/api/lists/$listId/items', null, null, const Duration(seconds: 20));
    final body = _jsonMap(response);
    final rawList = body['list'];
    final title = (rawList is Map) ? rawList['name'] as String? : null;
    return WishlistSnapshot(
      items: _items(body['items']),
      unpricedCount: (body['unpriced_count'] as num?)?.toInt() ?? 0,
      title: title,
      categories: _categories(body['categories']),
      list: rawList is Map ? WishList.fromJson(Map<String, dynamic>.from(rawList)) : null,
    );
  }

  Future<WishList> openInvite(String listId, String role) async {
    final response = await _send('POST', '/api/lists/$listId/invites/$role');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> regenerateInvite(String listId, String role) async {
    final response = await _send('POST', '/api/lists/$listId/invites/$role/regenerate');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> disableInvite(String listId, String role) async {
    final response = await _send('DELETE', '/api/lists/$listId/invites/$role');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<WishList> acceptInvite(String code) async {
    final response = await _send('POST', '/api/invites/$code/accept');
    return WishList.fromJson(_jsonMap(response));
  }

  Future<List<ListMember>> inviteByEmail(String listId, String email, String role) async {
    final response = await _send('POST', '/api/lists/$listId/members', {'email': email, 'role': role});
    return _memberList(_jsonMap(response)['members']);
  }

  Future<List<ListMember>> changeMemberRole(String listId, String userId, String role) async {
    final response = await _send('PATCH', '/api/lists/$listId/members/$userId', {'role': role});
    return _memberList(_jsonMap(response)['members']);
  }

  Future<List<ListMember>> removeMember(String listId, String userId) async {
    final response = await _send('DELETE', '/api/lists/$listId/members/$userId');
    return _memberList(_jsonMap(response)['members']);
  }

  Future<void> leaveList(String listId) async {
    await _send('POST', '/api/lists/$listId/leave');
  }

  Future<WishItem> reserveItem(String id, {String? name}) async {
    final response = await _send('POST', '/api/items/$id/reservation', {'name': name ?? ''});
    return WishItem.fromJson(_jsonMap(response));
  }

  Future<WishCategory> createCategory(String listId, String name) async {
    final response = await _send('POST', '/api/lists/$listId/categories', {'name': name});
    return WishCategory.fromJson(_jsonMap(response));
  }

  Future<WishCategory> renameCategory(String id, String name) async {
    final response = await _send('PATCH', '/api/categories/$id', {'name': name});
    return WishCategory.fromJson(_jsonMap(response));
  }

  Future<void> deleteCategory(String id) async {
    await _send('DELETE', '/api/categories/$id');
  }

  Future<List<WishCategory>> reorderCategories(String listId, List<String> ids) async {
    final response = await _send('POST', '/api/lists/$listId/categories/reorder', {'ids': ids});
    return _categories(_jsonMap(response)['categories']);
  }

  Future<WishItem> createItem({required String listId, required String name, required String url, String? categoryId}) async {
    final response = await _send('POST', '/api/lists/$listId/items', {
      'name': name,
      'url': url,
      'category_id': ?categoryId,
    });
    return WishItem.fromJson(_jsonMap(response));
  }

  Future<WishItem> updateItem(
    String id, {
    String? name,
    String? url,
    String? imageUrl,
    double? price,
    String? currency,
    bool clearPrice = false,
    bool clearImage = false,
    String? categoryId,
    bool setCategory = false,
    bool? purchased,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (url != null) payload['url'] = url;
    if (clearImage) {
      payload['image_url'] = '';
    } else if (imageUrl != null) {
      payload['image_url'] = imageUrl;
    }
    if (clearPrice) {
      payload['price'] = null;
    } else if (price != null) {
      payload['price'] = price;
    }
    if (currency != null) payload['currency'] = currency;
    if (setCategory) payload['category_id'] = categoryId;
    if (purchased != null) payload['purchased'] = purchased;
    final response = await _send('PATCH', '/api/items/$id', payload);
    return WishItem.fromJson(_jsonMap(response));
  }

  Future<WishItem> refreshItem(String id) async {
    final response = await _send('POST', '/api/items/$id/refresh');
    return WishItem.fromJson(_jsonMap(response));
  }

  Future<void> deleteItem(String id) async {
    await _send('DELETE', '/api/items/$id');
  }

  Future<void> clearOwnedReservation(String id) async {
    await _send('DELETE', '/api/items/$id/reservation');
  }

  Future<WishlistSnapshot> sharedList(String shareToken, {String? claims}) async {
    final response = await _send('GET', '/api/share/$shareToken', null, {
      if (claims != null && claims.isNotEmpty) 'x-claims': claims,
    });
    final body = _jsonMap(response);
    return WishlistSnapshot(
      items: _items(body['items']),
      unpricedCount: (body['unpriced_count'] as num?)?.toInt() ?? 0,
      title: (body['list'] as Map?)?['name'] as String?,
      categories: _categories(body['categories']),
    );
  }

  Future<String> reserve(String shareToken, String itemId, {String? name}) async {
    final response = await _send('POST', '/api/share/$shareToken/items/$itemId/reservation', {'name': name ?? ''});
    return _jsonMap(response)['claim_token'] as String;
  }

  Future<void> clearReservation(String shareToken, String itemId, String claimToken) async {
    await _send('DELETE', '/api/share/$shareToken/items/$itemId/reservation', null, {'x-claim-token': claimToken});
  }

  List<ListMember> _memberList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map) ListMember.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  List<WishList> _lists(dynamic raw) {
    final lists = <WishList>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          lists.add(WishList.fromJson(entry));
        } else if (entry is Map) {
          lists.add(WishList.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return lists;
  }

  List<WishCategory> _categories(dynamic raw) {
    final categories = <WishCategory>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          categories.add(WishCategory.fromJson(entry));
        } else if (entry is Map) {
          categories.add(WishCategory.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    categories.sort((a, b) => a.position.compareTo(b.position));
    return categories;
  }

  List<WishItem> _items(dynamic raw) {
    final items = <WishItem>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          items.add(WishItem.fromJson(entry));
        } else if (entry is Map) {
          items.add(WishItem.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return items;
  }

  Future<http.Response> _send(String method, String path, [Object? body, Map<String, String>? headers, Duration timeout = const Duration(seconds: 45)]) async {
    final uri = Uri.parse('$root$path');
    final request = http.Request(method, uri)..headers['accept'] = 'application/json';
    final current = token;
    if (current != null && current.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $current';
    }
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request).timeout(timeout);
      final text = await response.stream.bytesToString().timeout(timeout);
      final wrapped = http.Response(text, response.statusCode, headers: response.headers);
      if (response.statusCode >= 400) {
        throw ApiException(_detail(text, response.statusCode));
      }
      return wrapped;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('O servidor demorou demais para responder. Tente de novo.');
    } catch (_) {
      throw ApiException('Não foi possível falar com o servidor.');
    }
  }

  Map<String, dynamic> _jsonMap(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw ApiException('Resposta inesperada do servidor.');
  }

  String _detail(String body, int status) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } catch (_) {}
    if (status == 404) return 'Não encontramos esse item.';
    return 'Não foi possível concluir agora.';
  }
}
