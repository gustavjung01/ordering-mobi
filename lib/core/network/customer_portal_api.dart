import 'api_failure.dart';
import 'customer_portal_client.dart';
import 'customer_portal_models.dart';

abstract class CustomerOrderingRemote {
  Future<CustomerProfile> getProfile() => throw UnimplementedError();

  Future<CustomerCatalogPage> listCatalog({
    int limit = 50,
    int offset = 0,
    String? search,
    String? categoryId,
    String? purchaseMode,
    bool includeCategories = true,
  }) =>
      throw UnimplementedError();

  Future<CustomerCatalogItem?> getProductBySku(String sku) =>
      throw UnimplementedError();

  Future<List<CustomerCatalogItem>> listAllCatalog() =>
      throw UnimplementedError();

  Future<List<DeliveryAddress>> listDeliveryAddresses() =>
      throw UnimplementedError();

  Future<CustomerOrder> submitOrder({
    required String addressId,
    required String orderNote,
    required List<CartLine> lines,
    required String idempotencyKey,
  }) =>
      throw UnimplementedError();

  Future<List<CustomerOrder>> listOrders() => throw UnimplementedError();

  Future<CustomerOrder?> getOrderById(String orderId) =>
      throw UnimplementedError();

  Future<CustomerOrder> cancelOrder({
    required String orderId,
    required String idempotencyKey,
  }) =>
      throw UnimplementedError();
}

class CustomerPortalApi extends CustomerOrderingRemote {
  CustomerPortalApi(this._client);

  static const _pageSize = 50;
  static const _pageBatchSize = 4;
  static const _maxCatalogItems = 10000;

  final CustomerPortalClient _client;

  @override
  Future<CustomerProfile> getProfile() async {
    final data = await _client.requestData('GET', 'me');
    try {
      return CustomerProfile.fromJson(_map(data['profile']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<CustomerCatalogPage> listCatalog({
    int limit = 50,
    int offset = 0,
    String? search,
    String? categoryId,
    String? purchaseMode,
    bool includeCategories = true,
  }) async {
    final safeLimit = limit < 1 ? 1 : (limit > 50 ? 50 : limit);
    final safeOffset = offset < 0 ? 0 : offset;
    final parameters = <String, String>{
      'limit': '$safeLimit',
      'offset': '$safeOffset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (categoryId?.trim().isNotEmpty == true)
        'categoryId': categoryId!.trim(),
      if (purchaseMode?.trim().isNotEmpty == true)
        'purchaseMode': purchaseMode!.trim(),
      if (includeCategories) 'includeCategories': '1',
    };
    final query = Uri(queryParameters: parameters).query;
    final data = await _client.requestData('GET', 'catalog?$query');
    try {
      return CustomerCatalogPage.fromJson(data);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<CustomerCatalogItem?> getProductBySku(String sku) async {
    final normalized = sku.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final page = await listCatalog(
      search: normalized,
      limit: _pageSize,
      offset: 0,
      includeCategories: false,
    );
    for (final item in page.items) {
      if (item.sku.trim().toUpperCase() == normalized) return item;
    }
    return null;
  }

  @override
  Future<List<CustomerCatalogItem>> listAllCatalog() async {
    final items = <CustomerCatalogItem>[];
    for (
      var startOffset = 0;
      startOffset < _maxCatalogItems;
      startOffset += _pageSize * _pageBatchSize
    ) {
      final offsets = <int>[
        for (var index = 0; index < _pageBatchSize; index += 1)
          startOffset + index * _pageSize,
      ].where((offset) => offset < _maxCatalogItems).toList(growable: false);

      final pages = await Future.wait(
        offsets.map(
          (offset) => listCatalog(
            limit: _pageSize,
            offset: offset,
            includeCategories: false,
          ),
        ),
      );

      var reachedEnd = false;
      for (final page in pages) {
        items.addAll(page.items);
        if (!page.hasMore || page.items.length < _pageSize) {
          reachedEnd = true;
          break;
        }
      }
      if (reachedEnd) break;
    }
    return List.unmodifiable(items);
  }

  @override
  Future<List<DeliveryAddress>> listDeliveryAddresses() async {
    final data = await _client.requestData('GET', 'addresses');
    final addresses = data['addresses'];
    if (addresses is! List) throw _invalidResponse();

    try {
      return addresses
          .map((item) => DeliveryAddress.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<CustomerOrder> submitOrder({
    required String addressId,
    required String orderNote,
    required List<CartLine> lines,
    required String idempotencyKey,
  }) async {
    final data = await _client.requestData(
      'POST',
      'orders',
      idempotencyKey: idempotencyKey,
      body: {
        'addressId': addressId,
        'orderNote': orderNote,
        'lines': lines.map((line) => line.toJson()).toList(growable: false),
      },
    );
    try {
      return CustomerOrder.fromJson(_map(data['order']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<List<CustomerOrder>> listOrders() async {
    final data = await _client.requestData('GET', 'orders');
    final orders = data['orders'];
    if (orders is! List) throw _invalidResponse();
    try {
      return orders
          .map((item) => CustomerOrder.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<CustomerOrder?> getOrderById(String orderId) async {
    final normalized = orderId.trim();
    if (normalized.isEmpty) return null;
    try {
      final data = await _client.requestData(
        'GET',
        'orders/${Uri.encodeComponent(normalized)}',
      );
      return CustomerOrder.fromJson(_map(data['order']));
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on FormatException {
      throw _invalidResponse();
    }
  }

  @override
  Future<CustomerOrder> cancelOrder({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final data = await _client.requestData(
      'POST',
      'orders/${Uri.encodeComponent(orderId.trim())}/cancel',
      idempotencyKey: idempotencyKey,
      body: const <String, dynamic>{},
    );
    try {
      return CustomerOrder.fromJson(_map(data['order']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw const FormatException('Expected object');
  }

  static ApiFailure _invalidResponse() {
    return const ApiFailure(
      code: 'API_RESPONSE_INVALID',
      message: 'Dữ liệu trả về chưa hợp lệ.',
    );
  }
}
