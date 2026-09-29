import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/network/api_failure.dart';
import 'package:ordering_mobile/features/assistant/data/customer_assistant_api.dart';

void main() {
  test('assistant calls the PWA BFF with Clerk bearer token', () async {
    late http.Request captured;
    final api = CustomerAssistantApi(
      endpoint: Uri.parse('https://ordering.example/api/assistant/chat'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'replyText': 'Anh/chị có thể tìm sản phẩm từ mục Sản phẩm.',
            'credit': {
              'limitUsd': '5.00',
              'usedUsd': '1.25',
              'remainingUsd': '3.75',
              'usagePercent': '25',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final reply = await api.send(
      sessionId: '123e4567-e89b-42d3-a456-426614174000',
      message: 'Hướng dẫn tôi tìm sản phẩm',
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://ordering.example/api/assistant/chat',
    );
    expect(captured.headers['Authorization'], 'Bearer clerk-token');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['sessionId'], '123e4567-e89b-42d3-a456-426614174000');
    expect(body['message'], 'Hướng dẫn tôi tìm sản phẩm');
    expect(reply.text, contains('mục Sản phẩm'));
    expect(reply.credit?.remainingUsd, '3.75');
    api.close();
  });

  test('assistant preserves credit-limit business error', () async {
    final api = CustomerAssistantApi(
      endpoint: Uri.parse('https://ordering.example/api/assistant/chat'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': false,
            'code': 'AI_CREDIT_LIMIT_REACHED',
            'error': 'Hạn mức hỗ trợ AI đã sử dụng hết. Các chức năng đặt hàng khác vẫn hoạt động bình thường.',
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.send(
        sessionId: '123e4567-e89b-42d3-a456-426614174000',
        message: 'Tư vấn sản phẩm',
      ),
      throwsA(
        isA<ApiFailure>()
            .having(
              (failure) => failure.code,
              'code',
              'AI_CREDIT_LIMIT_REACHED',
            )
            .having((failure) => failure.statusCode, 'statusCode', 429),
      ),
    );
    api.close();
  });

  test('assistant rejects messages longer than PWA contract', () async {
    var requested = false;
    final api = CustomerAssistantApi(
      endpoint: Uri.parse('https://ordering.example/api/assistant/chat'),
      tokenProvider: () async => 'clerk-token',
      client: MockClient((request) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.send(
        sessionId: '123e4567-e89b-42d3-a456-426614174000',
        message: 'a' * 1001,
      ),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.code,
          'code',
          'ASSISTANT_MESSAGE_TOO_LONG',
        ),
      ),
    );
    expect(requested, isFalse);
    api.close();
  });
}
