class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.retryable = false,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool retryable;

  @override
  String toString() =>
      'ApiFailure(' + code + ', statusCode: ' + statusCode.toString() + ')';
}
