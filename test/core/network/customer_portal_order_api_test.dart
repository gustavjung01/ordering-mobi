import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/network/customer_portal_api.dart';
import 'package:ordering_mobile/core/network/customer_portal_client.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';

void main() {
  test(
    'submit order uses Customer Portal BFF and idempotency header',
    () async {
      late http.Request captured;
      final client = CustomerPortalClient(
        baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
        tokenProvider: () async => 'clerk-token',
        client: MockClient((request) async {
          captured = request;
          return _orderResponse();
        }),
      );
      final api = CustomerPortalApi(client);

      await api.submitOrder(
        addressId: 'address-1',
        orderNote: 'Giao sáng',
        lines: const [
          CartLine(sku: 'SKU-1', quantity: 2, note: 'Nguyên thùng'),
        ],
        idempotencyKey:
            'customer-order-submit-123e4567-e89b-42d3-a456-426614174000',
      );

      expect(
        captured.url.toString(),
        'https://ordering.example/api/customer-portal/orders',
      );
      expect(captured.method, 'POST');
      expect(
        captured.headers['Idempotency-Key'],
        'customer-order-submit-123e4567-e89b-42d3-a456-426614174000',
      );
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['addressId'], 'address-1');
      expect((body['lines'] as List).single['sku'], 'SKU-1');
      expect((body['lines'] as List).single['quantity'], 2);
      client.close();
    },
  );

  test('cancel uses order cancel BFF path and idempotency header', () async {
    late http.Request captured;
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        captured = request;
        return _orderResponse(status: 'CANCELLED');
      }),
    );
    final api = CustomerPortalApi(client);

    final order = await api.cancelOrder(
      orderId: 'order-1',
      idempotencyKey:
          'customer-order-cancel-123e4567-e89b-42d3-a456-426614174000',
    );

    expect(
      captured.url.toString(),
      'https://ordering.example/api/customer-portal/orders/order-1/cancel',
    );
    expect(captured.method, 'POST');
    expect(
      captured.headers['Idempotency-Key'],
      'customer-order-cancel-123e4567-e89b-42d3-a456-426614174000',
    );
    expect(order.status, 'CANCELLED');
    client.close();
  });
}

http.Response _orderResponse({String status = 'SUBMITTED'}) {
  return http.Response(
    jsonEncode({
      'data': {
        'order': {
          'id': 'order-1',
          'code': 'SO-001',
          'submittedAt': '2026-09-29T00:00:00.000Z',
          'status': status,
          'statusTimeline': [
            {'status': status, 'at': '2026-09-29T00:00:00.000Z'},
          ],
          'address': {
            'id': 'address-1',
            'label': 'Cửa hàng',
            'recipientName': 'Minh Anh',
            'phone': '0900000000',
            'addressLine': 'Địa chỉ giao hàng',
            'isDefault': true,
          },
          'lines': [
            {
              'sku': 'SKU-1',
              'productName': 'Sản phẩm 1',
              'packaging': 'Gói',
              'unit': 'Gói',
              'quantity': 2,
              'note': '',
              'unitPrice': 10000,
              'currency': 'VND',
            },
          ],
          'totalQuantity': 2,
          'pricedSubtotal': 20000,
          'hasPendingPrice': false,
          'orderNote': 'Giao sáng',
          'submissionKey':
              'customer-order-submit-123e4567-e89b-42d3-a456-426614174000',
        },
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
