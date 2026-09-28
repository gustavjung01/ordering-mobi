import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';

void main() {
  test('maps Customer Portal order contract', () {
    final order = CustomerOrder.fromJson({
      'id': 'order-1',
      'code': 'SO-001',
      'submittedAt': '2026-09-29T00:00:00.000Z',
      'status': 'SUBMITTED',
      'statusTimeline': [
        {
          'status': 'SUBMITTED',
          'at': '2026-09-29T00:00:00.000Z',
          'note': 'Đơn đã được gửi từ ứng dụng.',
        },
      ],
      'address': {
        'id': 'address-1',
        'label': 'Cửa hàng',
        'recipientName': 'Minh Anh',
        'phone': '0900000000',
        'addressLine': 'Địa chỉ giao hàng',
        'isDefault': false,
      },
      'lines': [
        {
          'sku': 'SKU-1',
          'productName': 'Sản phẩm 1',
          'packaging': 'GOI',
          'unit': 'GOI',
          'quantity': 2,
          'note': 'Giao nguyên thùng',
          'unitPrice': '120000',
          'currency': 'VND',
        },
      ],
      'totalQuantity': 2,
      'pricedSubtotal': '240000',
      'hasPendingPrice': false,
      'orderNote': 'Giao sáng',
      'submissionKey': 'customer-order-submit-123e4567-e89b-42d3-a456-426614174000',
    });

    expect(order.id, 'order-1');
    expect(order.lines.single.unitPrice, 120000);
    expect(order.pricedSubtotal, 240000);
    expect(order.isCancellable, isTrue);
    expect(order.address.recipientName, 'Minh Anh');
  });

  test('only submitted or received orders are cancellable in mobile UX', () {
    CustomerOrder order(String status) => CustomerOrder(
      id: 'id',
      code: 'SO',
      submittedAt: DateTime.utc(2026),
      status: status,
      statusTimeline: const [],
      address: const DeliveryAddress(
        id: 'a',
        label: 'L',
        recipientName: 'R',
        phone: 'P',
        addressLine: 'A',
        isDefault: false,
      ),
      lines: const [],
      totalQuantity: 0,
      pricedSubtotal: 0,
      hasPendingPrice: false,
      orderNote: '',
      submissionKey: '',
    );

    expect(order('SUBMITTED').isCancellable, isTrue);
    expect(order('RECEIVED').isCancellable, isTrue);
    expect(order('CONFIRMED').isCancellable, isFalse);
    expect(order('PROCESSING').isCancellable, isFalse);
    expect(order('CANCELLED').isCancellable, isFalse);
  });
}
