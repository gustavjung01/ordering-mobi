import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Đặt nhanh chỉ còn tìm kiếm và danh sách full width', () {
    final source = File(
      'lib/features/quick_order/presentation/quick_order_screen.dart',
    ).readAsStringSync();

    expect(source, contains('search: _searchController.text'));
    expect(source, contains('child: _QuickResults('));
    expect(source, contains('IconButton.filled('));
    expect(source, contains('AppTheme.brand'));

    for (final removed in [
      '_QuickFilterRail',
      '_RailLabel',
      '_categoryId',
      '_subcategoryId',
      '_purchaseMode',
      '_categories',
      '_rootCategories',
      '_subcategories',
      '_selectMode',
      '_selectCategory',
      '_selectSubcategory',
      'categoryId: _selectedCategoryId',
      'purchaseMode: _purchaseMode',
      'includeCategories:',
    ]) {
      expect(source, isNot(contains(removed)), reason: removed);
    }
  });

  test('Card Sản phẩm chỉ còn ảnh tên giá và vẫn mở chi tiết', () {
    final source = File(
      'lib/features/products/presentation/product_catalog_screen.dart',
    ).readAsStringSync();
    final cardStart = source.indexOf('class _CatalogFamilyCard');
    final cardEnd = source.indexOf('class _ModePriceBox');
    final card = source.substring(cardStart, cardEnd);

    expect(source, contains('mainAxisExtent: 188'));
    expect(source, isNot(contains('childAspectRatio: .57')));
    expect(card, contains('CatalogProductVisual('));
    expect(card, contains('group.name'));
    expect(card, contains('_priceLabel(selected)'));
    expect(card, contains('onTap: onOpen'));
    expect(card, contains('AppTheme.brandDark'));
    expect(card, contains('Color(0xFF9A6B00)'));

    for (final removed in [
      'brandFor(',
      'productTypeFor(',
      'variantFor(',
      '_ModeButton',
      'add_shopping_cart',
      'onAdd',
      'onSelect',
      "label: 'Lẻ'",
      "label: 'Thùng'",
    ]) {
      expect(card, isNot(contains(removed)), reason: removed);
    }
  });

  test('Bottom sheet vẫn giữ chọn SKU giá số lượng và thêm giỏ', () {
    final source = File(
      'lib/features/products/presentation/product_catalog_screen.dart',
    ).readAsStringSync();
    final sheetStart = source.indexOf('Future<void> _openGroup(');
    final sheetEnd = source.indexOf('  @override\n  Widget build', sheetStart);
    final sheet = source.substring(sheetStart, sheetEnd);

    for (final retained in [
      'Vị / loại',
      'Dung tích / size',
      '_ModePriceBox(',
      "label: 'Mua lẻ'",
      "label: 'Mua thùng'",
      '_QuantityStepper(',
      'add_shopping_cart',
      'Thêm thùng vào giỏ',
      'Thêm lẻ vào giỏ',
      "Key('product-sheet-content')",
      "Key('product-quantity-row')",
      "Key('product-add-button')",
      'backgroundColor: Colors.white',
      'maxHeight: MediaQuery.sizeOf(context).height * .82',
    ]) {
      expect(sheet, contains(retained), reason: retained);
    }

    expect(sheet, isNot(contains('heightFactor: .9')));
    expect(sheet, contains('size: 88'));
  });
}
