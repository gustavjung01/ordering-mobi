import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_client.dart';

class AssistantCredit {
  const AssistantCredit({
    required this.limitUsd,
    required this.usedUsd,
    required this.remainingUsd,
    required this.usagePercent,
  });

  factory AssistantCredit.fromJson(Map<String, dynamic> json) {
    return AssistantCredit(
      limitUsd: _string(json['limitUsd']),
      usedUsd: _string(json['usedUsd']),
      remainingUsd: _string(json['remainingUsd']),
      usagePercent: _string(json['usagePercent']),
    );
  }

  final String limitUsd;
  final String usedUsd;
  final String remainingUsd;
  final String usagePercent;
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.credit,
  });

  final String text;
  final AssistantCredit? credit;
}

class CustomerAssistantApi {
  factory CustomerAssistantApi({
    required Uri endpoint,
    required CustomerTokenProvider tokenProvider,
    http.Client? client,
    Duration timeout = const Duration(seconds: 35),
  }) {
    return CustomerAssistantApi._(
      endpoint,
      tokenProvider,
      client ?? http.Client(),
      timeout,
    );
  }

  CustomerAssistantApi._(
    this._endpoint,
    this._tokenProvider,
    this._client,
    this.timeout,
  );

  final Uri _endpoint;
  final CustomerTokenProvider _tokenProvider;
  final http.Client _client;
  final Duration timeout;

  Future<AssistantReply> send({
    required String sessionId,
    required String message,
  }) async {
    if (_endpoint.scheme != 'https' ||
        _endpoint.host.isEmpty ||
        _endpoint.userInfo.isNotEmpty) {
      throw const ApiFailure(
        code: 'ASSISTANT_ENDPOINT_INVALID',
        message: 'Dịch vụ hỗ trợ chưa được cấu hình hợp lệ.',
      );
    }

    final normalizedSessionId = sessionId.trim();
    final normalizedMessage = message.trim();
    if (normalizedSessionId.isEmpty) {
      throw const ApiFailure(
        code: 'ASSISTANT_SESSION_REQUIRED',
        message: 'Không tạo được phiên hỗ trợ. Vui lòng thử lại.',
      );
    }
    if (normalizedMessage.isEmpty) {
      throw const ApiFailure(
        code: 'ASSISTANT_MESSAGE_REQUIRED',
        message: 'Vui lòng nhập câu hỏi.',
      );
    }
    if (normalizedMessage.length > 1000) {
      throw const ApiFailure(
        code: 'ASSISTANT_MESSAGE_TOO_LONG',
        message: 'Câu hỏi không được vượt quá 1.000 ký tự.',
      );
    }

    String? token;
    try {
      token = (await _tokenProvider())?.trim();
    } on Object {
      token = null;
    }
    if (token == null || token.isEmpty) {
      throw const ApiFailure(
        code: 'AUTH_REQUIRED',
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'sessionId': normalizedSessionId,
              'message': normalizedMessage,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(
        code: 'ASSISTANT_TIMEOUT',
        message: 'Hỗ trợ sản phẩm đang phản hồi chậm. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiFailure(
        code: 'ASSISTANT_NETWORK',
        message: 'Chưa thể kết nối hỗ trợ sản phẩm. Vui lòng thử lại.',
        retryable: true,
      );
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } on FormatException {
      body = const {};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body['code']?.toString() ?? 'AI_ASSISTANT_UNAVAILABLE';
      final message = body['error']?.toString().trim();
      throw ApiFailure(
        code: code,
        message: message?.isNotEmpty == true
            ? message!
            : response.statusCode == 401
            ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
            : response.statusCode == 429
            ? 'Hạn mức hỗ trợ AI đã sử dụng hết. Các chức năng đặt hàng khác vẫn hoạt động bình thường.'
            : 'Hỗ trợ sản phẩm đang tạm gián đoạn. Vui lòng thử lại sau.',
        statusCode: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }

    final replyText = body['replyText']?.toString().trim() ?? '';
    if (body['ok'] != true || replyText.isEmpty) {
      throw const ApiFailure(
        code: 'ASSISTANT_RESPONSE_INVALID',
        message: 'Phản hồi hỗ trợ chưa hợp lệ. Vui lòng thử lại.',
        retryable: true,
      );
    }

    AssistantCredit? credit;
    final rawCredit = body['credit'];
    if (rawCredit is Map) {
      try {
        credit = AssistantCredit.fromJson(
          rawCredit.map((key, value) => MapEntry(key.toString(), value)),
        );
      } on FormatException {
        credit = null;
      }
    }
    return AssistantReply(text: replyText, credit: credit);
  }

  void close() => _client.close();
}

String _string(Object? value) {
  if (value is String) return value;
  if (value != null) return value.toString();
  throw const FormatException('Expected string');
}
