import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/network/customer_portal_api.dart';
import 'package:ordering_mobile/core/network/customer_portal_client.dart';

void main() {
  test('maps profile, catalog and delivery address contracts', () async {
    final mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/me')) {
        return _jsonResponse({
          'data': {
            'profile': {
              'customerCode': 'KH001',
              'displayName': 'Cửa hàng Minh Anh',
              'phone': '0900000000',
              'outletName': 'Minh Anh',
            },
          },
        });
      }
      if (path.endsWith('/catalog')) {
        expect(request.url.queryParameters['limit'], '1');
        expect(request.url.queryParameters['includeCategories'], '1');
        return _jsonResponse({
          'data': {
            'items': [
              {
                'sku': 'SKU-1',
                'name': 'Sản phẩm 1',
                'variantName': 'Gói 1 kg',
                'unitCode': 'GOI',
                'price': {
                  'amount': 120000,
                  'currency': 'VND',
                  'status': 'available',
                },
              },
            ],
            'categories': [
              {
                'id': 'cat-1',
                'name': 'Nhóm 1',
                'shortName': 'Nhóm 1',
                'parentCategoryId': null,
              },
            ],
            'hasMore': false,
            'limit': 1,
            'offset': 0,
          },
        });
      }
      if (path.endsWith('/addresses')) {
        return _jsonResponse({
          'data': {
            'addresses': [
              {
                'id': 'addr-1',
                'label': 'Cửa hàng',
                'recipientName': 'Minh Anh',
                'phone': '0900000000',
                'addressLine': 'Địa chỉ giao hàng',
                'isDefault': true,
              },
            ],
          },
        });
      }
      return http.Response('{}', 404);
    });
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'session-token',
      client: mockClient,
    );
    final api = CustomerPortalApi(client);

    final profile = await api.getProfile();
    final catalog = await api.listCatalog(limit: 1);
    final addresses = await api.listDeliveryAddresses();

    expect(profile.customerCode, 'KH001');
    expect(catalog.items.single.sku, 'SKU-1');
    expect(catalog.categories.single.id, 'cat-1');
    expect(addresses.single.isDefault, isTrue);
    client.close();
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}
