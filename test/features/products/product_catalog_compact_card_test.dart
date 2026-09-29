import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card Sản phẩm gọn chỉ giữ tên và giá ở phần thông tin', () {
    final source = File(
      'lib/features/products/presentation/product_catalog_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'class _CatalogFamilyCard extends StatelessWidget {',
    );
    final end = source.indexOf(
      'class _ModeButton extends StatelessWidget {',
      start,
    );
    final card = source.substring(start, end);

    expect(source, contains('childAspectRatio: .70'));
    expect(card, contains('size: 96'));
    expect(card, contains('group.name'));
    expect(card, contains('_priceLabel(selected)'));
    expect(card, contains("label: 'Lẻ'"));
    expect(card, contains("label: 'Thùng'"));
    expect(card, contains("tooltip: 'Thêm vào giỏ'"));

    expect(card, isNot(contains('brandFor(selected)')));
    expect(card, isNot(contains('subtitle')));
    expect(card, isNot(contains('variantFor(selected)')));
  });
}
