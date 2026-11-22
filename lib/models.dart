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
    this.addedByLabel,
    this.purchased = false,
    this.purchasedAt,
    this.purchasedByLabel,
    this.priority = 'quero',
    this.priceDrop,
    this.history = const [],
    this.position = 0,
    this.note,
    this.colorName,
    this.sizeLabel,
    this.voltage,
    this.quantity,
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
  final String? addedByLabel;
  final bool purchased;
  final DateTime? purchasedAt;
  final String? purchasedByLabel;
  final String priority;
  final double? priceDrop;
  final List<double> history;
  final int position;
  final String? note;
  final String? colorName;
  final String? sizeLabel;
  final String? voltage;
  final int? quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPrice => price != null;

  WishItem withPosition(int next) {
    return WishItem(
      id: id,
      name: name,
      url: url,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      imageUrl: imageUrl,
      price: price,
      currency: currency,
      store: store,
      message: message,
      listId: listId,
      categoryId: categoryId,
      reserved: reserved,
      reservedLabel: reservedLabel,
      reservedByMe: reservedByMe,
      addedByLabel: addedByLabel,
      purchased: purchased,
      purchasedAt: purchasedAt,
      purchasedByLabel: purchasedByLabel,
      priority: priority,
      priceDrop: priceDrop,
      history: history,
      position: next,
      note: note,
      colorName: colorName,
      sizeLabel: sizeLabel,
      voltage: voltage,
      quantity: quantity,
    );
  }

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
      addedByLabel: json['added_by_label'] as String?,
      purchased: json['purchased'] == true,
      purchasedAt: json['purchased_at'] == null ? null : DateTime.tryParse(json['purchased_at'] as String),
      purchasedByLabel: json['purchased_by_label'] as String?,
      priority: (json['priority'] as String?) ?? 'quero',
      priceDrop: _asDouble(json['price_drop']),
      history: [
        if (json['price_history'] is List)
          for (final point in json['price_history'] as List)
            if (point is Map && _asDouble(point['price']) != null) _asDouble(point['price'])!,
      ],
      position: (json['position'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      colorName: json['color'] as String?,
      sizeLabel: json['size_label'] as String?,
      voltage: json['voltage'] as String?,
      quantity: (json['quantity'] as num?)?.toInt(),
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
    this.list,
  });

  final List<WishItem> items;
  final int unpricedCount;
  final String? title;
  final List<WishCategory> categories;
  final WishList? list;

  List<MoneyTotal> get totals => sumItemPrices(items.where((item) => !item.purchased));

  List<MoneyTotal> get purchasedTotals => sumItemPrices(items.where((item) => item.purchased));
}

int compareWishItems(WishItem a, WishItem b) {
  if (a.purchased != b.purchased) return a.purchased ? 1 : -1;
  return b.createdAt.compareTo(a.createdAt);
}

List<WishItem> sortedWishItems(Iterable<WishItem> items) {
  final copy = [...items]..sort(compareWishItems);
  return copy;
}

List<MoneyTotal> sumItemPrices(Iterable<WishItem> items) {
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

class UserAccount {
  const UserAccount({required this.id, required this.email});

  final String id;
  final String email;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(id: json['id'] as String, email: json['email'] as String);
  }
}

class ListMember {
  const ListMember({
    required this.userId,
    required this.email,
    required this.label,
    required this.initials,
    required this.role,
  });

  final String userId;
  final String email;
  final String label;
  final String initials;
  final String role;

  factory ListMember.fromJson(Map<String, dynamic> json) {
    return ListMember(
      userId: json['user_id'] as String,
      email: (json['email'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      initials: (json['initials'] as String?) ?? '?',
      role: (json['role'] as String?) ?? 'viewer',
    );
  }
}

String roleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'Dono';
    case 'editor':
      return 'Pode editar';
    case 'viewer':
      return 'Só pode ver';
    default:
      return role;
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
    this.role = 'owner',
    this.collaborative = false,
    this.members = const [],
    this.inviteEditorUrl,
    this.inviteViewerUrl,
    this.purchasedTotals = const [],
    this.budget,
    this.budgetCurrency,
    this.showReservations = false,
    this.reservationsEnabled = true,
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
  final String role;
  final bool collaborative;
  final List<ListMember> members;
  final String? inviteEditorUrl;
  final String? inviteViewerUrl;
  final List<MoneyTotal> purchasedTotals;
  final double? budget;
  final String? budgetCurrency;
  final bool showReservations;
  final bool reservationsEnabled;

  bool get canEdit => role != 'viewer';
  bool get isOwner => role == 'owner';

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
      role: (json['role'] as String?) ?? 'owner',
      collaborative: json['collaborative'] == true,
      members: _members(json['members']),
      inviteEditorUrl: json['invite_editor_url'] as String?,
      inviteViewerUrl: json['invite_viewer_url'] as String?,
      purchasedTotals: _moneyList(json['purchased_totals']),
      budget: _asDouble(json['budget']),
      budgetCurrency: json['budget_currency'] as String?,
      showReservations: json['show_reservations'] == true,
      reservationsEnabled: json['reservations_enabled'] != false,
    );
  }
}

List<MoneyTotal> _moneyList(dynamic raw) {
  if (raw is! List) return const [];
  final totals = <MoneyTotal>[];
  for (final entry in raw) {
    if (entry is Map) {
      totals.add(MoneyTotal((entry['currency'] as String?) ?? '', _asDouble(entry['amount']) ?? 0));
    }
  }
  return totals;
}

List<ListMember> _members(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (entry is Map) ListMember.fromJson(Map<String, dynamic>.from(entry)),
  ];
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
