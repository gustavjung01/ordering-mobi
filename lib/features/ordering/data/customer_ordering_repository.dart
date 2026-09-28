
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/idempotency/canonical_idempotency.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_api.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../core/session/session_store.dart';
import '../../../core/storage/ordering_local_store.dart';

class CustomerOrderingRepository extends ChangeNotifier {
  CustomerOrderingRepository({
    required CustomerOrderingRemote remote,
    required OrderingLocalStore localStore,
    required SecureStringStore secureStore,
    required String userId,
  }) : _remote = remote,
       _localStore = localStore,
       _secureStore = secureStore,
       _userScope = Uri.encodeComponent(userId.trim());

  static const _cartStorageKey = 'cart.v1';
  static const _checkoutStorageKey = 'checkout.v1';
  static const _pendingSubmitStorageKey = 'pending-submit.v1';
  static const _pendingCancelPrefix = 'pending-cancel.v1.';

  final CustomerOrderingRemote _remote;
  final OrderingLocalStore _localStore;
  final SecureStringStore _secureStore;
  final String _userScope;

  CustomerCart _cart = CustomerCart.empty();
  CheckoutDraft _checkoutDraft = CheckoutDraft.empty();
  bool _initialized = false;
  Future<List<CustomerCatalogItem>>? _allCatalogFuture;

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
    _initialized = true;
    notifyListeners();
  }

  Future<CustomerCatalogPage> listCatalog({
    int limit = 50,
    int offset = 0,
    String? search,
    String? categoryId,
    String? purchaseMode,
    bool includeCategories = true,
  }) {
    return _remote.listCatalog(
      limit: limit,
      offset: offset,
      search: search,
      categoryId: categoryId,
      purchaseMode: purchaseMode,
      includeCategories: includeCategories,
    );
  }

  Future<List<CustomerCatalogItem>> listAllCatalog({bool refresh = false}) {
    if (refresh) _allCatalogFuture = null;
    final current = _allCatalogFuture;
    if (current != null) return current;
    final future = _remote.listAllCatalog();
    _allCatalogFuture = future;
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_allCatalogFuture, future)) _allCatalogFuture = null;
      },
    );
    return future;
  }

  Future<List<CustomerCatalogItem?>> productsForSkus(
    Iterable<String> skus,
  ) async {
    final unique = <String>[];
    final seen = <String>{};
    for (final sku in skus) {
      final normalized = sku.trim().toUpperCase();
      if (normalized.isNotEmpty && seen.add(normalized)) unique.add(normalized);
    }

    final results = <String, CustomerCatalogItem?>{};
    const batchSize = 8;
    for (var start = 0; start < unique.length; start += batchSize) {
      final end = start + batchSize < unique.length
          ? start + batchSize
          : unique.length;
      final batch = unique.sublist(start, end);
      final products = await Future.wait(batch.map(_remote.getProductBySku));
      for (var index = 0; index < batch.length; index += 1) {
        results[batch[index]] = products[index];
      }
    }
    return unique.map((sku) => results[sku]).toList(growable: false);
  }

  Future<void> addProduct(CustomerCatalogItem product, {int quantity = 1}) {
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
      lines.add(
        CartLine(
          sku: product.sku.trim().toUpperCase(),
          quantity: normalizedQuantity,
        ),
      );
    }
    return saveCart(
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
      await Future.wait([
        _localStore.delete(_localKey(_cartStorageKey)),
        _localStore.delete(_localKey(_checkoutStorageKey)),
        _secureStore.delete(pendingKey),
      ]);
      _cart = CustomerCart.empty();
      _checkoutDraft = CheckoutDraft.empty();
      notifyListeners();
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

    final catalog = await listAllCatalog();
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
      if (bySku.length >= 200) break;
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
