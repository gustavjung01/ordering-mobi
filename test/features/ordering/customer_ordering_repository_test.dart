import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/idempotency/canonical_idempotency.dart';
import 'package:ordering_mobile/core/network/api_failure.dart';
import 'package:ordering_mobile/core/network/customer_portal_api.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';
import 'package:ordering_mobile/core/session/session_store.dart';
import 'package:ordering_mobile/core/storage/ordering_local_store.dart';
import 'package:ordering_mobile/features/ordering/data/customer_ordering_repository.dart';

class _MemoryStore implements OrderingLocalStore, SecureStringStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FakeRemote extends CustomerOrderingRemote {
  int submitFailuresRemaining = 0;
  int cancelFailuresRemaining = 0;
  final submitKeys = <String>[];
  final cancelKeys = <String>[];
  List<CustomerCatalogItem> catalog = const [];

  @override
  Future<CustomerOrder> submitOrder({
    required String addressId,
    required String orderNote,
    required List<CartLine> lines,
    required String idempotencyKey,
  }) async {
    submitKeys.add(idempotencyKey);
    if (submitFailuresRemaining > 0) {
      submitFailuresRemaining -= 1;
      throw const ApiFailure(
        code: 'API_TIMEOUT',
        message: 'Timeout',
        retryable: true,
      );
    }
    return _order(idempotencyKey: idempotencyKey, lines: lines);
  }

  @override
  Future<CustomerOrder> cancelOrder({
    required String orderId,
    required String idempotencyKey,
  }) async {
    cancelKeys.add(idempotencyKey);
    if (cancelFailuresRemaining > 0) {
      cancelFailuresRemaining -= 1;
      throw const ApiFailure(
        code: 'API_TIMEOUT',
        message: 'Timeout',
        retryable: true,
      );
    }
    return _order(idempotencyKey: 'submit-key', status: 'CANCELLED');
  }

  @override
  Future<CustomerOrder?> getOrderById(String orderId) async =>
      _order(idempotencyKey: 'submit-key');

  @override
  Future<List<CustomerCatalogItem>> listAllCatalog() async => catalog;
}

void main() {
  test('submit retry after repository restart reuses exact key', () async {
    final local = _MemoryStore();
    final secure = _MemoryStore();
    final remote = _FakeRemote()..submitFailuresRemaining = 1;

    final first = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await first.initialize();
    await first.saveCart(
      CustomerCart(
        lines: const [CartLine(sku: 'SKU-1', quantity: 2)],
        updatedAt: DateTime.utc(2026, 9, 29),
      ),
    );

    await expectLater(
      first.submitOrder(addressId: 'address-1', orderNote: 'Giao sáng'),
      throwsA(isA<ApiFailure>()),
    );
    expect(remote.submitKeys, hasLength(1));
    expect(CanonicalIdempotencyKey.isValid(remote.submitKeys.single), isTrue);

    final second = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await second.initialize();
    final order = await second.submitOrder(
      addressId: 'address-1',
      orderNote: 'Giao sáng',
    );

    expect(remote.submitKeys, hasLength(2));
    expect(remote.submitKeys[1], remote.submitKeys[0]);
    expect(order.submissionKey, remote.submitKeys[0]);
    expect(second.cart.lines, isEmpty);
  });

  test('changed submit payload gets a new canonical key', () async {
    final local = _MemoryStore();
    final secure = _MemoryStore();
    final remote = _FakeRemote()..submitFailuresRemaining = 1;
    final repository = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await repository.initialize();
    await repository.saveCart(
      CustomerCart(
        lines: const [CartLine(sku: 'SKU-1', quantity: 1)],
        updatedAt: DateTime.utc(2026, 9, 29),
      ),
    );

    await expectLater(
      repository.submitOrder(addressId: 'address-1', orderNote: 'A'),
      throwsA(isA<ApiFailure>()),
    );
    await repository.submitOrder(addressId: 'address-1', orderNote: 'B');

    expect(remote.submitKeys[1], isNot(remote.submitKeys[0]));
    expect(CanonicalIdempotencyKey.isValid(remote.submitKeys[1]), isTrue);
  });

  test('cancel retry after repository restart reuses exact key', () async {
    final local = _MemoryStore();
    final secure = _MemoryStore();
    final remote = _FakeRemote()..cancelFailuresRemaining = 1;

    final first = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await first.initialize();
    await expectLater(
      first.cancelOrder('order-1'),
      throwsA(isA<ApiFailure>()),
    );

    final second = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await second.initialize();
    await second.cancelOrder('order-1');

    expect(remote.cancelKeys, hasLength(2));
    expect(remote.cancelKeys[1], remote.cancelKeys[0]);
    expect(CanonicalIdempotencyKey.isValid(remote.cancelKeys[0]), isTrue);
  });

  test('reorder caps quantity and skips unavailable SKUs', () async {
    final local = _MemoryStore();
    final secure = _MemoryStore();
    final remote = _FakeRemote()
      ..catalog = const [
        CustomerCatalogItem(
          sku: 'SKU-1',
          name: 'Sản phẩm 1',
          variantName: 'Gói',
          price: CustomerProductPrice(
            amount: 10000,
            currency: 'VND',
            status: 'available',
          ),
        ),
      ];
    final repository = CustomerOrderingRepository(
      remote: remote,
      localStore: local,
      secureStore: secure,
      userId: 'user-1',
    );
    await repository.initialize();
    await repository.saveCart(
      CustomerCart(
        lines: const [CartLine(sku: 'SKU-1', quantity: 998)],
        updatedAt: DateTime.utc(2026, 9, 29),
      ),
    );

    final result = await repository.reorderOrder('order-1');

    expect(result.addedLineCount, 1);
    expect(result.skippedLineCount, 1);
    expect(result.cart.lines.single.quantity, 999);
  });
}

CustomerOrder _order({
  required String idempotencyKey,
  String status = 'SUBMITTED',
  List<CartLine>? lines,
}) {
  final orderLines = lines ??
      const [
        CartLine(sku: 'SKU-1', quantity: 2),
        CartLine(sku: 'SKU-2', quantity: 1),
      ];
  return CustomerOrder(
    id: 'order-1',
    code: 'SO-001',
    submittedAt: DateTime.utc(2026, 9, 29),
    status: status,
    statusTimeline: [
      OrderStatusEvent(
        status: status,
        at: DateTime.utc(2026, 9, 29),
      ),
    ],
    address: const DeliveryAddress(
      id: 'address-1',
      label: 'Cửa hàng',
      recipientName: 'Minh Anh',
      phone: '0900000000',
      addressLine: 'Địa chỉ giao hàng',
      isDefault: true,
    ),
    lines: [
      for (final line in orderLines)
        CustomerOrderLine(
          sku: line.sku,
          productName: 'Sản phẩm ${line.sku}',
          packaging: 'Gói',
          unit: 'Gói',
          quantity: line.quantity,
          note: line.note,
          unitPrice: 10000,
          currency: 'VND',
        ),
    ],
    totalQuantity: orderLines.fold(0, (sum, line) => sum + line.quantity),
    pricedSubtotal: 30000,
    hasPendingPrice: false,
    orderNote: '',
    submissionKey: idempotencyKey,
  );
}
