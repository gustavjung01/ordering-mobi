import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Đơn hàng có tab con Sản phẩm đã mua và đặt lại nhanh', () {
    final source = File(
      'lib/features/orders/presentation/orders_screen.dart',
    ).readAsStringSync();

    expect(source, contains("Key('orders-sub-tabs')"));
    expect(source, contains("Text('Đơn hàng')"));
    expect(source, contains("Text('Sản phẩm đã mua')"));
    expect(source, contains("'Tìm sản phẩm đã mua'"));
    expect(source, contains('_buildPurchasedProducts'));
    expect(source, contains('productsForSkus(history.keys)'));
    expect(source, contains('refreshCatalogPrices(available)'));
    expect(source, contains('quantity: purchased.latestLine.quantity'));
    expect(source, contains("'Đặt lại'"));
    expect(source, contains("'Tạm ngừng bán'"));
    expect(source, contains('CatalogProductVisual('));
  });

  test('Bộ lọc trạng thái chỉ nằm trong tab Đơn hàng', () {
    final source = File(
      'lib/features/orders/presentation/orders_screen.dart',
    ).readAsStringSync();

    expect(source, contains('if (_view == _OrdersView.orders)'));
    expect(source, contains('for (final status in _statuses)'));
    expect(source, contains("status == 'ALL' ? 'Tất cả'"));
  });
}
