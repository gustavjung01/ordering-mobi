import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/idempotency/canonical_idempotency.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_api.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../core/session/session_store.dart';
import '../../../core/storage/catalog_local_store.dart';
import '../../../core/storage/ordering_local_store.dart';

class CustomerOrderingRepository extends ChangeNotifier {
  CustomerOrderingRepository(
    this._remote,
    this._localStore,
    this._secureStore, {
    required String userId,
    CustomerCatalogStore? catalogStore,
  }) : _userScope = Uri.encodeComponent(userId.trim()),
       _catalogStore = catalogStore ?? MemoryCustomerCatalogStore();

  static const _cartStorageKey = 'cart.v1';
  static const _checkoutStorageKey = 'checkout.v1';
  static const _pendingSubmitStorageKey = 'pending-submit.v1';
  static const _pendingCancelPrefix = 'pending-cancel.v1.';

  final CustomerOrderingRemote _remote;
  final OrderingLocalStore _localStore;
  final SecureStringStore _secureStore;
  final String _userScope;
  final CustomerCatalogStore _catalogStore;

  CustomerCart _cart = CustomerCart.empty();
  CheckoutDraft _checkoutDraft = CheckoutDraft.empty();
  bool _initialized = false;
  List<CustomerCatalogItem> _catalogItems = const [];
  List<CustomerCategory> _catalogCategories = const [];
  String? _catalogCursor;
  Future<void>? _catalogSyncFuture;
  bool _backgroundCatalogSyncStarted = false;

  bool get initialized => _initialized;
  CustomerCart get cart => _cart;
  CheckoutDraft get checkoutDraft => _checkoutDraft;
  int get cartQuantity => _cart.totalQuantity;

  String _localKey(String name) => 'ordering.user.$_userScope.$name';
  String _secureKey(String name) => 'ordering.user.$_userScope.$name';

  Future<void> initialize() async {
    final values = await Future.wait([
      _localStore.read(_localKey(_cartStorageKey)),
      _localStore.read(_localKey(_checkoutStorageKey)),
    ]);
    _cart = _decodeCart(values[0]);
    _checkoutDraft = _decodeCheckoutDraft(values[1]);
    _applyCatalogSnapshot(await _catalogStore.read(_userScope));
    _initialized = true;
    notifyListeners();
  }

  void _applyCatalogSnapshot(CatalogLocalSnapshot snapshot) {
    _catalogCursor = snapshot.cursor;
    _catalogItems = List.unmodifiable(snapshot.items);
    _catalogCategories = List.unmodifiable(snapshot.categories);
  }

  Future<void> _syncCatalog({bool forceFull = false}) {
    final current = _catalogSyncFuture;
    if (current != null) return current;

    final future = () async {
      final sync = await _remote.syncCatalog(
        since: forceFull ? null : _catalogCursor,
      );
      await _catalogStore.applySync(_userScope, sync);
      _applyCatalogSnapshot(await _catalogStore.read(_userScope));
    }();
    _catalogSyncFuture = future;
    return future.whenComplete(() {
      if (identical(_catalogSyncFuture, future)) _catalogSyncFuture = null;
    });
  }

  Future<void> _ensureCatalog({bool refresh = false}) async {
    if (_catalogItems.isEmpty) {
      await _syncCatalog(forceFull: true);
      return;
    }
    if (refresh) {
      await _syncCatalog();
      return;
    }
    if (!_backgroundCatalogSyncStarted) {
      _backgroundCatalogSyncStarted = true;
      unawaited(
        _syncCatalog().catchError((Object _) {
          _backgroundCatalogSyncStarted = false;
        }),
      );
    }
  }

  Future<CustomerCatalogPage> listCatalog({
    int limit = 50,
    int offset = 0,
    String? search,
    String? categoryId,
    String? purchaseMode,
    bool includeCategories = true,
  }) async {
    await _ensureCatalog();
    final normalizedSearch = search?.trim().toLowerCase() ?? '';
    final normalizedCategory = categoryId?.trim() ?? '';
    final normalizedMode = purchaseMode?.trim().toLowerCase() ?? '';
    final filtered = _catalogItems.where((item) {
      if (normalizedCategory.isNotEmpty &&
          item.categoryId != normalizedCategory &&
          item.parentCategoryId != normalizedCategory) {
        return false;
      }
      if (normalizedMode.isNotEmpty && item.purchaseMode != normalizedMode) {
        return false;
      }
      if (normalizedSearch.isNotEmpty) {
        final haystack = [
          item.sku,
          item.productCode ?? '',
          item.name,
          item.variantName,
          item.categoryName ?? '',
          item.parentCategoryName ?? '',
          item.brandName ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(normalizedSearch)) return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((left, right) {
        final product = (left.productCode ?? left.sku).compareTo(
          right.productCode ?? right.sku,
        );
        return product != 0 ? product : left.sku.compareTo(right.sku);
      });

    final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    final safeOffset = offset < 0 ? 0 : offset;
    final end = safeOffset + safeLimit < filtered.length
        ? safeOffset + safeLimit
        : filtered.length;
    final page = safeOffset >= filtered.length
        ? const <CustomerCatalogItem>[]
        : filtered.sublist(safeOffset, end);
    return CustomerCatalogPage(
      items: List.unmodifiable(page),
      categories: includeCategories
          ? List.unmodifiable(_catalogCategories)
          : const [],
      hasMore: end < filtered.length,
      limit: safeLimit,
      offset: safeOffset,
    );
  }

  Future<List<CustomerCatalogItem>> listAllCatalog({bool refresh = false}) async {
    await _ensureCatalog(refresh: refresh);
    return List.unmodifiable(_catalogItems);
  }

  Future<List<CustomerCatalogItem>> refreshCatalogPrices(
    Iterable<CustomerCatalogItem> items,
  ) async {
    final requested = items.toList(growable: false);
    final prices = await _remote.resolveCatalogPrices(requested);
    if (prices.isEmpty) return requested;

    await _catalogStore.updatePrices(_userScope, prices);
    _catalogItems = List.unmodifiable([
      for (final item in _catalogItems)
        if (item.variantId != null && prices.containsKey(item.variantId))
          item.copyWithPrice(prices[item.variantId]!)
        else
          item,
    ]);

    return [
      for (final item in requested)
        if (item.variantId != null && prices.containsKey(item.variantId))
          item.copyWithPrice(prices[item.variantId]!)
        else
          item,
    ];
  }

  Future<List<CustomerCatalogItem?>> productsForSkus(
    Iterable<String> skus,
  ) async {
    await _ensureCatalog();
    final bySku = <String, CustomerCatalogItem>{
      for (final item in _catalogItems) item.sku.trim().toUpperCase(): item,
    };
    final unique = <String>[];
    final seen = <String>{};
    for (final sku in skus) {
      final normalized = sku.trim().toUpperCase();
      if (normalized.isNotEmpty && seen.add(normalized)) unique.add(normalized);
    }
    return unique.map((sku) => bySku[sku]).toList(growable: false);
  }

  Future<void> addProduct(
    CustomerCatalogItem product, {
    int quantity = 1,
  }) async {
    final normalizedQuantity = _clampQuantity(quantity);
    final lines = [..._cart.lines];
    final index = lines.indexWhere(
      (line) => line.sku == product.sku.trim().toUpperCase(),
    );
    if (index >= 0) {
      lines[index] = lines[index].copyWith(
        quantity: _clampQuantity(lines[index].quantity + normalizedQuantity),
      );
    } else {
      if (lines.length >= 200) {
        throw const ApiFailure(
          code: 'ORDER_TOO_MANY_LINES',
          message: 'Giỏ hàng không được vượt quá 200 dòng.',
        );
      }
      lines.add(
        CartLine(
          sku: product.sku.trim().toUpperCase(),
          quantity: normalizedQuantity,
        ),
      );
    }
    await saveCart(
      CustomerCart(lines: lines, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> updateCartLine(
    String sku, {
    int? quantity,
    String? note,
  }) {
    final normalizedSku = sku.trim().toUpperCase();
    final lines = _cart.lines
        .map(
          (line) => line.sku == normalizedSku
              ? line.copyWith(
                  quantity: quantity == null
                      ? line.quantity
                      : _clampQuantity(quantity),
                  note: note == null ? line.note : _sanitizeLineNote(note),
                )
              : line,
        )
        .toList(growable: false);
    return saveCart(
      CustomerCart(lines: lines, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> removeCartLine(String sku) {
    final normalizedSku = sku.trim().toUpperCase();
    return saveCart(
      CustomerCart(
        lines: _cart.lines
            .where((line) => line.sku != normalizedSku)
            .toList(growable: false),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> clearCart() => saveCart(
    CustomerCart(lines: const [], updatedAt: DateTime.now().toUtc()),
  );

  Future<void> saveCart(CustomerCart cart) async {
    _cart = _sanitizeCart(cart);
    await _localStore.write(
      _localKey(_cartStorageKey),
      jsonEncode(_cart.toJson()),
    );
    notifyListeners();
  }

  Future<void> saveCheckoutDraft({
    required String? addressId,
    required String orderNote,
  }) async {
    final note = orderNote.length > 500
        ? orderNote.substring(0, 500)
        : orderNote;
    _checkoutDraft = CheckoutDraft(
      addressId: addressId?.trim().isEmpty == true ? null : addressId?.trim(),
      orderNote: note,
      updatedAt: DateTime.now().toUtc(),
    );
    await _localStore.write(
      _localKey(_checkoutStorageKey),
      jsonEncode(_checkoutDraft.toJson()),
    );
    notifyListeners();
  }

  Future<List<DeliveryAddress>> listDeliveryAddresses() =>
      _remote.listDeliveryAddresses();

  Future<List<CustomerOrder>> listOrders() => _remote.listOrders();

  Future<CustomerOrder?> getOrderById(String orderId) =>
      _remote.getOrderById(orderId);

  Future<CustomerOrder> submitOrder({
    required String addressId,
    required String orderNote,
  }) async {
    final normalizedAddressId = addressId.trim();
    if (normalizedAddressId.isEmpty) {
      throw const ApiFailure(
        code: 'DELIVERY_ADDRESS_REQUIRED',
        message: 'Vui lòng chọn địa chỉ nhận hàng.',
      );
    }
    if (_cart.lines.isEmpty) {
      throw const ApiFailure(
        code: 'ORDER_CART_EMPTY',
        message: 'Giỏ hàng đang trống.',
      );
    }
    if (_cart.lines.length > 200) {
      throw const ApiFailure(
        code: 'ORDER_TOO_MANY_LINES',
        message: 'Đơn hàng không được vượt quá 200 dòng.',
      );
    }
    if (orderNote.length > 500) {
      throw const ApiFailure(
        code: 'INVALID_ORDER_NOTE',
        message: 'Ghi chú đơn hàng không được vượt quá 500 ký tự.',
      );
    }

    final signature = jsonEncode({
      'addressId': normalizedAddressId,
      'orderNote': orderNote,
      'lines': _cart.lines.map((line) => line.toJson()).toList(growable: false),
    });
    final pendingKey = _secureKey(_pendingSubmitStorageKey);
    final pending = _decodePendingMutation(await _secureStore.read(pendingKey));
    final idempotencyKey =
        pending != null &&
            pending.signature == signature &&
            CanonicalIdempotencyKey.isValid(pending.key)
        ? pending.key
        : CanonicalIdempotencyKey.create('customer-order-submit');

    if (pending == null ||
        pending.signature != signature ||
        pending.key != idempotencyKey) {
      await _secureStore.write(
        pendingKey,
        jsonEncode({'key': idempotencyKey, 'signature': signature}),
      );
    }

    try {
      final order = await _remote.submitOrder(
        addressId: normalizedAddressId,
        orderNote: orderNote,
        lines: _cart.lines,
        idempotencyKey: idempotencyKey,
      );
      await _localStore.delete(_localKey(_cartStorageKey));
      try {
        await _localStore.delete(_localKey(_checkoutStorageKey));
      } on Object {
        // A stale checkout draft is harmless once the cart is cleared.
      }
      _cart = CustomerCart.empty();
      _checkoutDraft = CheckoutDraft.empty();
      notifyListeners();
      try {
        await _secureStore.delete(pendingKey);
      } on Object {
        // A stale pending key is replaced when a different payload is submitted.
      }
      return order;
    } on ApiFailure catch (error) {
      if (!error.retryable) await _secureStore.delete(pendingKey);
      rethrow;
    }
  }

  Future<CustomerOrder> cancelOrder(String orderId) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw const ApiFailure(
        code: 'ORDER_ID_REQUIRED',
        message: 'Không xác định được đơn hàng cần hủy.',
      );
    }
    final storageKey = _secureKey('$_pendingCancelPrefix$normalizedOrderId');
    var key = (await _secureStore.read(storageKey))?.trim();
    if (key == null || !CanonicalIdempotencyKey.isValid(key)) {
      key = CanonicalIdempotencyKey.create('customer-order-cancel');
      await _secureStore.write(storageKey, key);
    }

    try {
      final order = await _remote.cancelOrder(
        orderId: normalizedOrderId,
        idempotencyKey: key,
      );
      await _secureStore.delete(storageKey);
      return order;
    } on ApiFailure catch (error) {
      if (!error.retryable) await _secureStore.delete(storageKey);
      rethrow;
    }
  }

  Future<ReorderOrderResult> reorderOrder(String orderId) async {
    final order = await _remote.getOrderById(orderId);
    if (order == null) {
      throw const ApiFailure(
        code: 'CUSTOMER_PORTAL_ORDER_NOT_FOUND',
        message: 'Không tìm thấy đơn hàng.',
        statusCode: 404,
      );
    }

    final catalog = await listAllCatalog(refresh: true);
    final available = <String, CustomerCatalogItem>{
      for (final item in catalog) item.sku.trim().toUpperCase(): item,
    };
    final quantities = <String, CartLine>{
      for (final line in _cart.lines) line.sku: line,
    };
    var addedLineCount = 0;
    var skippedLineCount = 0;

    for (final orderLine in order.lines) {
      final sku = orderLine.sku.trim().toUpperCase();
      if (!available.containsKey(sku)) {
        skippedLineCount += 1;
        continue;
      }
      final current = quantities[sku];
      if (current == null && quantities.length >= 200) {
        skippedLineCount += 1;
        continue;
      }
      quantities[sku] = CartLine(
        sku: sku,
        quantity: _clampQuantity(
          (current?.quantity ?? 0) + orderLine.quantity,
        ),
        note: orderLine.note.trim().isNotEmpty
            ? _sanitizeLineNote(orderLine.note)
            : current?.note ?? '',
      );
      addedLineCount += 1;
    }

    if (addedLineCount == 0) {
      throw const ApiFailure(
        code: 'CUSTOMER_PORTAL_REORDER_UNAVAILABLE',
        message: 'Các mặt hàng trong đơn cũ hiện chưa thể thêm lại vào giỏ.',
        statusCode: 409,
      );
    }

    final next = CustomerCart(
      lines: quantities.values.toList(growable: false),
      updatedAt: DateTime.now().toUtc(),
    );
    await saveCart(next);
    return ReorderOrderResult(
      cart: _cart,
      addedLineCount: addedLineCount,
      skippedLineCount: skippedLineCount,
    );
  }

  @override
  void dispose() {
    unawaited(_catalogStore.close());
    super.dispose();
  }

  CustomerCart _decodeCart(String? value) {
    if (value == null || value.trim().isEmpty) return CustomerCart.empty();
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return CustomerCart.empty();
      return _sanitizeCart(
        CustomerCart.fromJson(
          decoded.map((key, item) => MapEntry(key.toString(), item)),
        ),
      );
    } on Object {
      return CustomerCart.empty();
    }
  }

  CheckoutDraft _decodeCheckoutDraft(String? value) {
    if (value == null || value.trim().isEmpty) return CheckoutDraft.empty();
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return CheckoutDraft.empty();
      final draft = CheckoutDraft.fromJson(
        decoded.map((key, item) => MapEntry(key.toString(), item)),
      );
      return CheckoutDraft(
        addressId: draft.addressId,
        orderNote: draft.orderNote.length > 500
            ? draft.orderNote.substring(0, 500)
            : draft.orderNote,
        updatedAt: draft.updatedAt,
      );
    } on Object {
      return CheckoutDraft.empty();
    }
  }

  CustomerCart _sanitizeCart(CustomerCart value) {
    final bySku = <String, CartLine>{};
    for (final line in value.lines) {
      final sku = line.sku.trim().toUpperCase();
      if (sku.isEmpty) continue;
      bySku[sku] = CartLine(
        sku: sku,
        quantity: _clampQuantity(line.quantity),
        note: _sanitizeLineNote(line.note),
      );
    }
    return CustomerCart(
      lines: bySku.values.toList(growable: false),
      updatedAt: value.updatedAt,
    );
  }

  int _clampQuantity(int value) {
    if (value < 1) return 1;
    if (value > 999) return 999;
    return value;
  }

  String _sanitizeLineNote(String value) {
    final trimmed = value.trim();
    return trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
  }

  _PendingMutation? _decodePendingMutation(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final key = decoded['key']?.toString() ?? '';
      final signature = decoded['signature']?.toString() ?? '';
      if (key.isEmpty || signature.isEmpty) return null;
      return _PendingMutation(key: key, signature: signature);
    } on Object {
      return null;
    }
  }
}

class _PendingMutation {
  const _PendingMutation({required this.key, required this.signature});

  final String key;
  final String signature;
}
