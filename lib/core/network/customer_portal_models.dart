class CustomerProfile {
  const CustomerProfile({
    required this.customerCode,
    required this.displayName,
    required this.phone,
    required this.outletName,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      customerCode: _string(json, 'customerCode'),
      displayName: _string(json, 'displayName'),
      phone: _string(json, 'phone'),
      outletName: _string(json, 'outletName'),
    );
  }

  final String customerCode;
  final String displayName;
  final String phone;
  final String outletName;
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.isDefault,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: _string(json, 'id'),
      label: _string(json, 'label'),
      recipientName: _string(json, 'recipientName'),
      phone: _string(json, 'phone'),
      addressLine: _string(json, 'addressLine'),
      isDefault: json['isDefault'] == true,
    );
  }

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String addressLine;
  final bool isDefault;
}

class CustomerCategory {
  const CustomerCategory({
    required this.id,
    required this.name,
    required this.shortName,
    this.parentCategoryId,
  });

  factory CustomerCategory.fromJson(Map<String, dynamic> json) {
    return CustomerCategory(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      shortName: _string(json, 'shortName'),
      parentCategoryId: json['parentCategoryId']?.toString(),
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String? parentCategoryId;
}

class CustomerProductPrice {
  const CustomerProductPrice({
    required this.amount,
    required this.currency,
    required this.status,
  });

  factory CustomerProductPrice.fromJson(Map<String, dynamic> json) {
    final amountValue = json['amount'];
    return CustomerProductPrice(
      amount: amountValue is num ? amountValue.toDouble() : null,
      currency: _string(json, 'currency'),
      status: _string(json, 'status'),
    );
  }

  final double? amount;
  final String currency;
  final String status;
}

class CustomerCatalogItem {
  const CustomerCatalogItem({
    required this.sku,
    required this.name,
    required this.variantName,
    required this.unitCode,
    required this.price,
  });

  factory CustomerCatalogItem.fromJson(Map<String, dynamic> json) {
    final priceJson = _map(json['price']);
    return CustomerCatalogItem(
      sku: _string(json, 'sku'),
      name: _string(json, 'name'),
      variantName: _string(json, 'variantName'),
      unitCode: json['unitCode']?.toString(),
      price: CustomerProductPrice.fromJson(priceJson),
    );
  }

  final String sku;
  final String name;
  final String variantName;
  final String? unitCode;
  final CustomerProductPrice price;
}

class CustomerCatalogPage {
  const CustomerCatalogPage({
    required this.items,
    required this.categories,
    required this.hasMore,
    required this.limit,
    required this.offset,
  });

  factory CustomerCatalogPage.fromJson(Map<String, dynamic> json) {
    return CustomerCatalogPage(
      items: _list(json, 'items')
          .map((item) => CustomerCatalogItem.fromJson(_map(item)))
          .toList(growable: false),
      categories: _list(json, 'categories')
          .map((item) => CustomerCategory.fromJson(_map(item)))
          .toList(growable: false),
      hasMore: json['hasMore'] == true,
      limit: _integer(json, 'limit'),
      offset: _integer(json, 'offset'),
    );
  }

  final List<CustomerCatalogItem> items;
  final List<CustomerCategory> categories;
  final bool hasMore;
  final int limit;
  final int offset;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid $key');
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Missing or invalid $key');
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null && key == 'categories') return const [];
  if (value is List) return value;
  throw FormatException('Missing or invalid $key');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Expected object');
}
