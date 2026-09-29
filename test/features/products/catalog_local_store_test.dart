import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';
import 'package:ordering_mobile/core/storage/catalog_local_store.dart';

void main() {
  test('catalog local áp delta upsert và tombstone theo user scope', () async {
    final store = MemoryCustomerCatalogStore();
    const first = CustomerCatalogItem(
      sku: 'SKU-1',
      variantId: 'v1',
      name: 'Sản phẩm 1',
      variantName: 'Lẻ',
      price: CustomerProductPrice(
        amount: null,
        currency: 'VND',
        status: 'customer_price_pending',
      ),
    );
    const second = CustomerCatalogItem(
      sku: 'SKU-2',
      variantId: 'v2',
      name: 'Sản phẩm 2',
      variantName: 'Lẻ',
      price: CustomerProductPrice(
        amount: null,
        currency: 'VND',
        status: 'customer_price_pending',
      ),
    );

    await store.applySync(
      'user-a',
      const CustomerCatalogSync(
        cursor: '2026-09-29T00:00:00.000Z',
        full: true,
        upserts: [first, second],
        removeVariantIds: [],
        categories: [],
      ),
    );
    await store.applySync(
      'user-a',
      const CustomerCatalogSync(
        cursor: '2026-09-29T01:00:00.000Z',
        full: false,
        upserts: [],
        removeVariantIds: ['v1'],
        categories: [],
      ),
    );

    final snapshot = await store.read('user-a');
    expect(snapshot.cursor, '2026-09-29T01:00:00.000Z');
    expect(snapshot.items.map((item) => item.sku), ['SKU-2']);
    expect((await store.read('user-b')).items, isEmpty);
  });

  test('catalog local giữ dữ liệu tĩnh khi cập nhật giá theo variant', () async {
    final store = MemoryCustomerCatalogStore();
    const product = CustomerCatalogItem(
      sku: 'SKU-1',
      variantId: 'v1',
      name: 'Sản phẩm 1',
      variantName: 'Lẻ',
      price: CustomerProductPrice(
        amount: null,
        currency: 'VND',
        status: 'customer_price_pending',
      ),
    );
    await store.applySync(
      'user-a',
      const CustomerCatalogSync(
        cursor: '2026-09-29T00:00:00.000Z',
        full: true,
        upserts: [product],
        removeVariantIds: [],
        categories: [],
      ),
    );
    await store.updatePrices(
      'user-a',
      const {
        'v1': CustomerProductPrice(
          amount: 125000,
          currency: 'VND',
          status: 'available',
        ),
      },
    );

    final item = (await store.read('user-a')).items.single;
    expect(item.name, 'Sản phẩm 1');
    expect(item.price.amount, 125000);
    expect(item.price.isAvailable, isTrue);
  });
}
