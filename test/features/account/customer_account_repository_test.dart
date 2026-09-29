import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/idempotency/canonical_idempotency.dart';
import 'package:ordering_mobile/core/network/api_failure.dart';
import 'package:ordering_mobile/core/network/customer_portal_account_api.dart';
import 'package:ordering_mobile/core/network/customer_portal_account_models.dart';
import 'package:ordering_mobile/core/network/customer_portal_client.dart';
import 'package:ordering_mobile/core/session/session_store.dart';
import 'package:ordering_mobile/features/account/data/customer_account_repository.dart';

class _MemorySecureStore implements SecureStringStore {
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

void main() {
  test('registration retry after repository restart reuses exact key', () async {
    final secure = _MemorySecureStore();
    final keys = <String>[];
    var attempts = 0;
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        keys.add(request.headers['Idempotency-Key'] ?? '');
        attempts += 1;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'CUSTOMER_PORTAL_UNAVAILABLE',
                'message': 'Tạm thời chưa kết nối được.',
                'retryable': true,
              },
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return _lifecycleResponse();
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

    final first = CustomerAccountRepository(
      api,
      secure,
      userId: 'user-1',
    );
    await expectLater(
      first.submitRegistration(input),
      throwsA(isA<ApiFailure>()),
    );

    final second = CustomerAccountRepository(
      api,
      secure,
      userId: 'user-1',
    );
    final lifecycle = await second.submitRegistration(input);

    expect(lifecycle.state, PortalLifecycleStates.submitted);
    expect(keys, hasLength(2));
    expect(keys[1], keys[0]);
    expect(CanonicalIdempotencyKey.isValid(keys[0]), isTrue);
    client.close();
  });

  test('changed registration payload gets a new canonical key', () async {
    final secure = _MemorySecureStore();
    final keys = <String>[];
    var attempts = 0;
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        keys.add(request.headers['Idempotency-Key'] ?? '');
        attempts += 1;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'API_TIMEOUT',
                'message': 'Timeout',
                'retryable': true,
              },
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return _lifecycleResponse();
      }),
    );
    final repository = CustomerAccountRepository(
      CustomerPortalAccountApi(client),
      secure,
      userId: 'user-1',
    );

    await expectLater(
      repository.submitRegistration(
        const PortalRegistrationInput(
          name: 'Điểm bán Minh Anh',
          phone: '0900000000',
          businessType: 'Cửa hàng bán lẻ',
          addressLine1: '125 Nguyễn Văn Linh',
          ward: 'Phường Tân Phong',
          province: 'Thành phố Hồ Chí Minh',
        ),
      ),
      throwsA(isA<ApiFailure>()),
    );

    await repository.submitRegistration(
      const PortalRegistrationInput(
        name: 'Điểm bán Minh Anh',
        phone: '0900000001',
        businessType: 'Cửa hàng bán lẻ',
        addressLine1: '125 Nguyễn Văn Linh',
        ward: 'Phường Tân Phong',
        province: 'Thành phố Hồ Chí Minh',
      ),
    );

    expect(keys, hasLength(2));
    expect(keys[1], isNot(keys[0]));
    expect(CanonicalIdempotencyKey.isValid(keys[1]), isTrue);
    client.close();
  });
}

http.Response _lifecycleResponse() {
  return http.Response(
    jsonEncode({
      'data': {
        'state': PortalLifecycleStates.submitted,
        'registration': null,
        'profile': null,
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
