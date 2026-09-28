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
      parentCategoryId: _optionalString(json['parentCategoryId']),
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
    return CustomerProductPrice(
      amount: _nullableNumber(json['amount']),
      currency: _string(json, 'currency'),
      status: _string(json, 'status'),
    );
  }

  final double? amount;
  final String currency;
  final String status;

  bool get isAvailable => status == 'available' && amount != null;
}

class CustomerCatalogItem {
  const CustomerCatalogItem({
    required this.sku,
    required this.name,
    required this.variantName,
    required this.price,
    this.variantId,
    this.productId,
    this.productCode,
    this.categoryId,
    this.categoryName,
    this.parentCategoryId,
    this.parentCategoryName,
    this.brandName,
    this.purchaseMode = 'retail',
    this.unitCode,
    this.unitName,
    this.conversionToBase,
  });

  factory CustomerCatalogItem.fromJson(Map<String, dynamic> json) {
    return CustomerCatalogItem(
      sku: _string(json, 'sku'),
      name: _string(json, 'name'),
      variantName: _string(json, 'variantName'),
      price: CustomerProductPrice.fromJson(_map(json['price'])),
      variantId: _optionalString(json['variantId']),
      productId: _optionalString(json['productId']),
      productCode: _optionalString(json['productCode']),
      categoryId: _optionalString(json['categoryId']),
      categoryName: _optionalString(json['categoryName']),
      parentCategoryId: _optionalString(json['parentCategoryId']),
      parentCategoryName: _optionalString(json['parentCategoryName']),
      brandName: _optionalString(json['brandName']),
      purchaseMode: _optionalString(json['purchaseMode']) ?? 'retail',
      unitCode: _optionalString(json['unitCode']),
      unitName: _optionalString(json['unitName']),
      conversionToBase: _nullableNumber(json['conversionToBase']),
    );
  }

  final String sku;
  final String name;
  final String variantName;
  final String? variantId;
  final String? productId;
  final String? productCode;
  final String? categoryId;
  final String? categoryName;
  final String? parentCategoryId;
  final String? parentCategoryName;
  final String? brandName;
  final String purchaseMode;
  final String? unitCode;
  final String? unitName;
  final double? conversionToBase;
  final CustomerProductPrice price;

  String get unitLabel => unitName?.trim().isNotEmpty == true
      ? unitName!.trim()
      : unitCode?.trim().isNotEmpty == true
      ? unitCode!.trim()
      : 'đơn vị';

  String get categoryLabel =>
      parentCategoryName?.trim().isNotEmpty == true
          ? parentCategoryName!.trim()
          : categoryName?.trim().isNotEmpty == true
          ? categoryName!.trim()
          : '';
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

class CartLine {
  const CartLine({
    required this.sku,
    required this.quantity,
    this.note = '',
  });

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      sku: _string(json, 'sku').trim().toUpperCase(),
      quantity: _integer(json, 'quantity'),
      note: _optionalString(json['note']) ?? '',
    );
  }

  final String sku;
  final int quantity;
  final String note;

  CartLine copyWith({int? quantity, String? note}) {
    return CartLine(
      sku: sku,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'sku': sku,
    'quantity': quantity,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

class CustomerCart {
  const CustomerCart({required this.lines, required this.updatedAt});

  factory CustomerCart.empty() {
    return CustomerCart(
      lines: const [],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  factory CustomerCart.fromJson(Map<String, dynamic> json) {
    return CustomerCart(
      lines: _list(json, 'lines')
          .map((item) => CartLine.fromJson(_map(item)))
          .toList(growable: false),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final List<CartLine> lines;
  final DateTime updatedAt;

  int get totalQuantity =>
      lines.fold<int>(0, (total, line) => total + line.quantity);

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class CheckoutDraft {
  const CheckoutDraft({
    required this.addressId,
    required this.orderNote,
    required this.updatedAt,
  });

  factory CheckoutDraft.empty() {
    return CheckoutDraft(
      addressId: null,
      orderNote: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  factory CheckoutDraft.fromJson(Map<String, dynamic> json) {
    return CheckoutDraft(
      addressId: _optionalString(json['addressId']),
      orderNote: _optionalString(json['orderNote']) ?? '',
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final String? addressId;
  final String orderNote;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'addressId': addressId,
    'orderNote': orderNote,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class CustomerOrderLine {
  const CustomerOrderLine({
    required this.sku,
    required this.productName,
    required this.packaging,
    required this.unit,
    required this.quantity,
    required this.note,
    required this.unitPrice,
    required this.currency,
  });

  factory CustomerOrderLine.fromJson(Map<String, dynamic> json) {
    return CustomerOrderLine(
      sku: _string(json, 'sku'),
      productName: _string(json, 'productName'),
      packaging: _string(json, 'packaging'),
      unit: _string(json, 'unit'),
      quantity: _integer(json, 'quantity'),
      note: _optionalString(json['note']) ?? '',
      unitPrice: _nullableNumber(json['unitPrice']),
      currency: _string(json, 'currency'),
    );
  }

  final String sku;
  final String productName;
  final String packaging;
  final String unit;
  final int quantity;
  final String note;
  final double? unitPrice;
  final String currency;
}

class OrderStatusEvent {
  const OrderStatusEvent({
    required this.status,
    required this.at,
    this.note = '',
  });

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) {
    return OrderStatusEvent(
      status: _string(json, 'status'),
      at: _dateTime(json['at']),
      note: _optionalString(json['note']) ?? '',
    );
  }

  final String status;
  final DateTime at;
  final String note;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.code,
    required this.submittedAt,
    required this.status,
    required this.statusTimeline,
    required this.address,
    required this.lines,
    required this.totalQuantity,
    required this.pricedSubtotal,
    required this.hasPendingPrice,
    required this.orderNote,
    required this.submissionKey,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: _string(json, 'id'),
      code: _string(json, 'code'),
      submittedAt: _dateTime(json['submittedAt']),
      status: _string(json, 'status'),
      statusTimeline: _list(json, 'statusTimeline')
          .map((item) => OrderStatusEvent.fromJson(_map(item)))
          .toList(growable: false),
      address: DeliveryAddress.fromJson(_map(json['address'])),
      lines: _list(json, 'lines')
          .map((item) => CustomerOrderLine.fromJson(_map(item)))
          .toList(growable: false),
      totalQuantity: _integer(json, 'totalQuantity'),
      pricedSubtotal: _number(json['pricedSubtotal']),
      hasPendingPrice: json['hasPendingPrice'] == true,
      orderNote: _optionalString(json['orderNote']) ?? '',
      submissionKey: _optionalString(json['submissionKey']) ?? '',
    );
  }

  final String id;
  final String code;
  final DateTime submittedAt;
  final String status;
  final List<OrderStatusEvent> statusTimeline;
  final DeliveryAddress address;
  final List<CustomerOrderLine> lines;
  final int totalQuantity;
  final double pricedSubtotal;
  final bool hasPendingPrice;
  final String orderNote;
  final String submissionKey;

  bool get isCancellable => status == 'SUBMITTED' || status == 'RECEIVED';
}

class ReorderOrderResult {
  const ReorderOrderResult({
    required this.cart,
    required this.addedLineCount,
    required this.skippedLineCount,
  });

  final CustomerCart cart;
  final int addedLineCount;
  final int skippedLineCount;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid $key');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Missing or invalid $key');
}

double _number(Object? value) {
  final number = _nullableNumber(value);
  if (number == null) throw const FormatException('Expected number');
  return number;
}

double? _nullableNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value.trim());
  }
  return null;
}

DateTime _dateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const FormatException('Expected ISO-8601 date');
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
