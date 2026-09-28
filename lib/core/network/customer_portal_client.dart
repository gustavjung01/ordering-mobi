import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_failure.dart';

typedef CustomerTokenProvider = Future<String?> Function();

class CustomerPortalClient {
  CustomerPortalClient({
    required this.baseUri,
    required this.tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final CustomerTokenProvider tokenProvider;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    if (!baseUri.hasScheme ||
        baseUri.scheme != 'https' ||
        baseUri.host.isEmpty) {
      throw const ApiFailure(
        code: 'API_BASE_URL_INVALID',
        message: 'Địa chỉ kết nối hệ thống chưa hợp lệ.',
      );
    }

    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiFailure(
        code: 'AUTH_REQUIRED',
        message: 'Vui lòng đăng nhập để tiếp tục.',
      );
    }

    final uri = baseUri.resolve(path);
    final request = http.Request(method.toUpperCase(), uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      request.headers['Idempotency-Key'] = idempotencyKey.trim();
    }

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(
        code: 'API_TIMEOUT',
        message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiFailure(
        code: 'API_NETWORK',
        message: 'Không kết nối được hệ thống. Vui lòng thử lại.',
        retryable: true,
      );
    }

    final response = await http.Response.fromStream(streamed);
    Object? decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final object = decoded is Map ? decoded : const <String, dynamic>{};
      final code = (object['code'] ?? object['error'] ?? 'API_ERROR')
          .toString();
      final message = (object['message'] ?? 'Không xử lý được yêu cầu.')
          .toString();
      final requestId =
          (object['requestId'] ?? response.headers['x-request-id'])?.toString();

      throw ApiFailure(
        code: code,
        message: message,
        statusCode: response.statusCode,
        requestId: requestId,
        retryable: response.statusCode >= 500,
      );
    }

    if (decoded == null) return const <String, dynamic>{};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const ApiFailure(
      code: 'API_RESPONSE_INVALID',
      message: 'Dữ liệu trả về chưa hợp lệ.',
    );
  }

  void close() => _client.close();
}
