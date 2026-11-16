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

  String imageProxy(WishItem item) {
    final version = item.updatedAt.millisecondsSinceEpoch;
    return '$root/api/items/${item.id}/image?v=$version';
  }

  Future<WishlistSnapshot> listItems() async {
    final response = await _send('GET', '/api/items');
    final body = _jsonMap(response);
    final rawItems = body['items'];
    final items = <WishItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(WishItem.fromJson(entry));
        } else if (entry is Map) {
          items.add(WishItem.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return WishlistSnapshot(items: items, unpricedCount: (body['unpriced_count'] as num?)?.toInt() ?? 0);
  }

  Future<WishItem> createItem({required String name, required String url}) async {
    final response = await _send('POST', '/api/items', {'name': name, 'url': url});
    return WishItem.fromJson(_jsonMap(response));
  }

  Future<WishItem> updateItem(
    String id, {
    String? name,
    String? imageUrl,
    double? price,
    String? currency,
    bool clearPrice = false,
    bool clearImage = false,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
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

  Future<http.Response> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$root$path');
    final request = http.Request(method, uri)..headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request).timeout(const Duration(seconds: 45));
      final text = await response.stream.bytesToString();
      final wrapped = http.Response(text, response.statusCode, headers: response.headers);
      if (response.statusCode >= 400) {
        throw ApiException(_detail(text, response.statusCode));
      }
      return wrapped;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('A loja demorou demais para responder. Tente de novo.');
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
