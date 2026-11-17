class WishItem {
  const WishItem({
    required this.id,
    required this.name,
    required this.url,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.price,
    this.currency,
    this.store,
    this.message,
    this.listId,
    this.categoryId,
    this.reserved = false,
    this.reservedLabel,
    this.reservedByMe = false,
  });

  final String id;
  final String name;
  final String url;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final String? store;
  final String status;
  final String? message;
  final String? listId;
  final String? categoryId;
  final bool reserved;
  final String? reservedLabel;
  final bool reservedByMe;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPrice => price != null;

  factory WishItem.fromJson(Map<String, dynamic> json) {
    return WishItem(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      imageUrl: json['image_url'] as String?,
      price: _asDouble(json['price']),
      currency: json['currency'] as String?,
      store: json['store'] as String?,
      status: (json['status'] as String?) ?? 'failed',
      message: json['message'] as String?,
      listId: json['list_id'] as String?,
      categoryId: json['category_id'] as String?,
      reserved: json['reserved'] == true,
      reservedLabel: json['reserved_label'] as String?,
      reservedByMe: json['reserved_by_me'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MoneyTotal {
  const MoneyTotal(this.currency, this.amount);

  final String currency;
  final double amount;
}

class WishCategory {
  const WishCategory({required this.id, required this.name, required this.position});

  final String id;
  final String name;
  final int position;

  factory WishCategory.fromJson(Map<String, dynamic> json) {
    return WishCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class WishlistSnapshot {
  const WishlistSnapshot({
    required this.items,
    required this.unpricedCount,
    this.title,
    this.categories = const [],
  });

  final List<WishItem> items;
  final int unpricedCount;
  final String? title;
  final List<WishCategory> categories;

  List<MoneyTotal> get totals {
    final buckets = <String, double>{};
    for (final item in items) {
      if (item.price == null) continue;
      final code = (item.currency ?? '').toUpperCase();
      buckets[code] = (buckets[code] ?? 0) + item.price!;
    }
    final keys = buckets.keys.toList()
      ..sort((a, b) {
        if (a == 'BRL') return -1;
        if (b == 'BRL') return 1;
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });
    return [for (final key in keys) MoneyTotal(key, buckets[key]!)];
  }
}

class UserAccount {
  const UserAccount({required this.id, required this.email});

  final String id;
  final String email;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(id: json['id'] as String, email: json['email'] as String);
  }
}

class WishList {
  const WishList({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.unpricedCount,
    required this.totals,
    this.shareToken,
    this.sharePath,
    this.shortCode,
    this.shortUrl,
  });

  final String id;
  final String name;
  final String? shareToken;
  final String? sharePath;
  final String? shortCode;
  final String? shortUrl;
  final int itemCount;
  final int unpricedCount;
  final List<MoneyTotal> totals;

  factory WishList.fromJson(Map<String, dynamic> json) {
    final rawTotals = json['totals'];
    final totals = <MoneyTotal>[];
    if (rawTotals is List) {
      for (final entry in rawTotals) {
        if (entry is Map) {
          totals.add(MoneyTotal((entry['currency'] as String?) ?? '', _asDouble(entry['amount']) ?? 0));
        }
      }
    }
    return WishList(
      id: json['id'] as String,
      name: json['name'] as String,
      shareToken: json['share_token'] as String?,
      sharePath: json['share_path'] as String?,
      shortCode: json['short_code'] as String?,
      shortUrl: json['short_url'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      unpricedCount: (json['unpriced_count'] as num?)?.toInt() ?? 0,
      totals: totals,
    );
  }
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
