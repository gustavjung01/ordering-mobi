import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/network/api_failure.dart';
import 'package:ordering_mobile/core/network/customer_portal_client.dart';

void main() {
  test('sends Clerk bearer token to the same-origin portal BFF', () async {
    late http.Request capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'data': {
            'profile': {'displayName': 'Khách hàng'},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'session-token',
      client: mockClient,
    );

    final data = await client.requestData('GET', 'me');

    expect(
      capturedRequest.url.toString(),
      'https://ordering.example/api/customer-portal/me',
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer session-token');
    expect(data['profile'], isA<Map>());
    client.close();
  });

  test('normalizes nested Customer Portal error envelope', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'CUSTOMER_PORTAL_ACCESS_DENIED',
            'message': 'Tài khoản chưa được phép đặt hàng.',
            'retryable': false,
          },
          'requestId': 'req_1',
        }),
        403,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => 'session-token',
      client: mockClient,
    );

    await expectLater(
      client.requestData('GET', 'me'),
      throwsA(
        isA<ApiFailure>()
            .having(
              (failure) => failure.code,
              'code',
              'CUSTOMER_PORTAL_ACCESS_DENIED',
            )
            .having((failure) => failure.requestId, 'requestId', 'req_1')
            .having((failure) => failure.retryable, 'retryable', isFalse),
      ),
    );
    client.close();
  });

  test('does not send a request without an authenticated session', () async {
    var requested = false;
    final mockClient = MockClient((request) async {
      requested = true;
      return http.Response('{}', 200);
    });
    final client = CustomerPortalClient(
      baseUri: Uri.parse('https://ordering.example/api/customer-portal/'),
      tokenProvider: () async => null,
      client: mockClient,
    );

    await expectLater(
      client.requestData('GET', 'me'),
      throwsA(isA<ApiFailure>().having(
        (failure) => failure.code,
        'code',
        'AUTH_REQUIRED',
      )),
    );
    expect(requested, isFalse);
    client.close();
  });
}
