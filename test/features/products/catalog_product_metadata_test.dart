import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';
import 'package:ordering_mobile/features/products/domain/catalog_product_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'canonical PWA metadata groups Berrino flavors into one product card',
    () async {
      final metadata = await CatalogMetadataIndex.load();
      final dauRetail = _item(
        sku: 'BERDAU-LE',
        productCode: 'BERDAU',
        purchaseMode: 'retail',
        amount: 89000,
      );
      final dauCase = _item(
        sku: 'BERDAU-THUNG',
        productCode: 'BERDAU',
        purchaseMode: 'case',
        amount: 1068000,
      );
      final mangCauRetail = _item(
        sku: 'BERMCA-LE',
        productCode: 'BERMCA',
        purchaseMode: 'retail',
        amount: 113000,
      );

      expect(
        metadata.groupKeyFor(dauRetail),
        metadata.groupKeyFor(mangCauRetail),
      );
      expect(metadata.groupNameFor(dauRetail), 'Sinh tố / mứt Berrino');
      expect(metadata.variantFor(dauRetail), 'DÂU');
      expect(metadata.variantFor(mangCauRetail), 'MÃNG CẦU');
      expect(metadata.imageUrlFor(dauRetail), endsWith('/BERDAU.webp'));

      final groups = buildCatalogProductGroups(
        [dauRetail, dauCase, mangCauRetail],
        metadata,
      );
      expect(groups, hasLength(1));
      expect(
        groups.single.variantLabels(metadata),
        containsAll(['DÂU', 'MÃNG CẦU']),
      );
      expect(groups.single.preferred().sku, 'BERDAU-LE');
      expect(
        groups.single.preferred(purchaseMode: 'case').sku,
        'BERDAU-THUNG',
      );
    },
  );

  test(
    'quick-order source list deduplicates exact SKU but keeps distinct SKUs',
    () {
      final first = _item(
        sku: 'SKU-001',
        productCode: 'BERDAU',
        purchaseMode: 'retail',
        amount: 89000,
      );
      final duplicate = _item(
        sku: 'sku-001',
        productCode: 'BERDAU',
        purchaseMode: 'retail',
        amount: 89000,
      );
      final caseItem = _item(
        sku: 'SKU-002',
        productCode: 'BERDAU',
        purchaseMode: 'case',
        amount: 1068000,
      );

      final deduped = dedupeCatalogItems([first, duplicate, caseItem]);

      expect(deduped, hasLength(2));
      expect(
        deduped.map((item) => item.sku.toUpperCase()),
        containsAll(['SKU-001', 'SKU-002']),
      );
    },
  );
}

CustomerCatalogItem _item({
  required String sku,
  required String productCode,
  required String purchaseMode,
  required double amount,
}) {
  return CustomerCatalogItem(
    sku: sku,
    name: 'Sinh tố Berrino',
    variantName: '1.35 kg',
    productCode: productCode,
    brandName: 'Berrino',
    purchaseMode: purchaseMode,
    unitCode: purchaseMode == 'case' ? 'THUNG' : 'CHAI',
    unitName: purchaseMode == 'case' ? 'Thùng' : 'Chai',
    price: CustomerProductPrice(
      amount: amount,
      currency: 'VND',
      status: 'available',
    ),
  );
}
