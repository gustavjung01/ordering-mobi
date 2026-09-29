import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/network/customer_portal_account_api.dart';
import 'package:ordering_mobile/core/network/customer_portal_account_models.dart';
import 'package:ordering_mobile/core/network/customer_portal_client.dart';

void main() {
  test('loads the current point-of-sale lifecycle', () async {
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://ordering.example/api/customer-portal/registrations/current',
        );
        expect(request.method, 'GET');
        return _lifecycleResponse();
      }),
    );
    final api = CustomerPortalAccountApi(client);

    final lifecycle = await api.getLifecycle();

    expect(lifecycle.state, PortalLifecycleStates.needMoreInfo);
    expect(lifecycle.registration?.version, 3);
    expect(lifecycle.registration?.proposedCustomer.name, 'Điểm bán Minh Anh');
    client.close();
  });

  test(
    'submits registration with canonical mutation header passthrough',
    () async {
      late http.Request captured;
      final client = CustomerPortalClient(
        baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
        tokenProvider: () async => 'clerk-token',
        client: MockClient((request) async {
          captured = request;
          return _lifecycleResponse(state: PortalLifecycleStates.submitted);
        }),
      );
      final api = CustomerPortalAccountApi(client);
      const input = PortalRegistrationInput(
        name: 'Điểm bán Minh Anh',
        phone: '0900000000',
        businessType: 'Cửa hàng bán lẻ',
        addressLine1: '125 Nguyễn Văn Linh',
        ward: 'Phường Tân Phong',
        province: 'Thành phố Hồ Chí Minh',
      );

      await api.submitRegistration(
        input: input,
        idempotencyKey:
            'customer-registration-submit-123e4567-e89b-42d3-a456-426614174000',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://ordering.example/api/customer-portal/registrations',
      );
      expect(
        captured.headers['Idempotency-Key'],
        'customer-registration-submit-123e4567-e89b-42d3-a456-426614174000',
      );
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      final proposed = body['proposedCustomer'] as Map<String, dynamic>;
      expect(proposed['name'], 'Điểm bán Minh Anh');
      expect(
        (proposed['address'] as Map<String, dynamic>)['countryCode'],
        'VN',
      );
      client.close();
    },
  );

  test('resubmits registration with expected version and same BFF contract', () async {
    late http.Request captured;
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        captured = request;
        return _lifecycleResponse(state: PortalLifecycleStates.submitted);
      }),
    );
    final api = CustomerPortalAccountApi(client);
    final lifecycle = PortalLifecycleSnapshot.fromJson(
      _lifecycleData(),
    );
    const input = PortalRegistrationInput(
      name: 'Điểm bán Minh Anh',
      phone: '0900000000',
      businessType: 'Cửa hàng bán lẻ',
      addressLine1: '125 Nguyễn Văn Linh',
      ward: 'Phường Tân Phong',
      province: 'Thành phố Hồ Chí Minh',
    );

    await api.resubmitRegistration(
      registration: lifecycle.registration!,
      input: input,
      idempotencyKey:
          'customer-registration-resubmit-123e4567-e89b-42d3-a456-426614174000',
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/customer-portal/registrations/reg-1/resubmit',
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['expectedVersion'], 3);
    client.close();
  });

  test('updates active profile using optimistic timestamps', () async {
    late http.Request captured;
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        captured = request;
        return _profileResponse();
      }),
    );
    final api = CustomerPortalAccountApi(client);

    final profile = await api.updateProfile(
      input: PortalProfileUpdateInput(
        outletName: 'Minh Anh',
        phone: '0900000000',
        expectedCustomerUpdatedAt: DateTime.parse(
          '2026-09-29T01:00:00.000Z',
        ),
        expectedAddressUpdatedAt: DateTime.parse(
          '2026-09-29T01:00:00.000Z',
        ),
        addressId: 'address-1',
        addressLine1: '125 Nguyễn Văn Linh',
        ward: 'Phường Tân Phong',
        province: 'Thành phố Hồ Chí Minh',
        countryCode: 'VN',
      ),
      idempotencyKey:
          'customer-profile-update-123e4567-e89b-42d3-a456-426614174000',
    );

    expect(captured.method, 'PATCH');
    expect(
      captured.url.toString(),
      'https://ordering.example/api/customer-portal/me',
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['expectedCustomerUpdatedAt'], '2026-09-29T01:00:00.000Z');
    expect((body['address'] as Map<String, dynamic>)['id'], 'address-1');
    expect(
      captured.headers['Idempotency-Key'],
      'customer-profile-update-123e4567-e89b-42d3-a456-426614174000',
    );
    expect(profile.customerCode, 'KH001');
    client.close();
  });
}

Map<String, dynamic> _lifecycleData({
  String state = PortalLifecycleStates.needMoreInfo,
}) {
  return {
    'state': state,
    'registration': {
      'id': 'reg-1',
      'status': 'NEED_MORE_INFO',
      'version': 3,
      'proposedCustomer': {
        'name': 'Điểm bán Minh Anh',
        'phone': '0900000000',
        'businessType': 'Cửa hàng bán lẻ',
        'address': {
          'label': 'Địa chỉ chính',
          'addressLine1': '125 Nguyễn Văn Linh',
          'addressLine2': null,
          'ward': 'Phường Tân Phong',
          'district': null,
          'province': 'Thành phố Hồ Chí Minh',
          'postalCode': null,
          'countryCode': 'VN',
        },
      },
      'reviewReason': 'Bổ sung địa chỉ.',
      'submittedAt': '2026-09-28T01:00:00.000Z',
      'updatedAt': '2026-09-29T01:00:00.000Z',
    },
    'profile': null,
  };
}

http.Response _lifecycleResponse({
  String state = PortalLifecycleStates.needMoreInfo,
}) {
  return http.Response(
    jsonEncode({'data': _lifecycleData(state: state)}),
    200,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _profileResponse() {
  return http.Response(
    jsonEncode({
      'data': {
        'profile': {
          'customerCode': 'KH001',
          'displayName': 'Cửa hàng Minh Anh',
          'outletName': 'Minh Anh',
          'phone': '0900000000',
          'customerUpdatedAt': '2026-09-29T01:05:00.000Z',
          'address': {
            'id': 'address-1',
            'label': 'Địa chỉ chính',
            'recipientName': 'Minh Anh',
            'phone': '0900000000',
            'locationUrl': '',
            'addressLine1': '125 Nguyễn Văn Linh',
            'addressLine2': '',
            'ward': 'Phường Tân Phong',
            'district': '',
            'province': 'Thành phố Hồ Chí Minh',
            'postalCode': '',
            'countryCode': 'VN',
            'isDefault': true,
            'updatedAt': '2026-09-29T01:05:00.000Z',
          },
        },
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
