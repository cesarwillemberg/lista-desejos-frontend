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

class WishlistSnapshot {
  const WishlistSnapshot({required this.items, required this.unpricedCount});

  final List<WishItem> items;
  final int unpricedCount;

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

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
