import 'api_failure.dart';
import 'customer_portal_account_models.dart';
import 'customer_portal_client.dart';

class CustomerPortalAccountApi {
  const CustomerPortalAccountApi(this._client);

  final CustomerPortalClient _client;

  Future<PortalLifecycleSnapshot> getLifecycle() async {
    final data = await _client.requestData('GET', 'registrations/current');
    try {
      return PortalLifecycleSnapshot.fromJson(data);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<PortalLifecycleSnapshot> submitRegistration({
    required PortalRegistrationInput input,
    required String idempotencyKey,
  }) async {
    final data = await _client.requestData(
      'POST',
      'registrations',
      body: input.toJson(),
      idempotencyKey: idempotencyKey,
    );
    try {
      return PortalLifecycleSnapshot.fromJson(data);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<PortalLifecycleSnapshot> resubmitRegistration({
    required PortalRegistration registration,
    required PortalRegistrationInput input,
    required String idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      ...input.toJson(),
      'expectedVersion': registration.version,
    };
    final data = await _client.requestData(
      'POST',
      'registrations/${Uri.encodeComponent(registration.id)}/resubmit',
      body: body,
      idempotencyKey: idempotencyKey,
    );
    try {
      return PortalLifecycleSnapshot.fromJson(data);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<PortalProfile> getProfile() async {
    final data = await _client.requestData('GET', 'me');
    try {
      return PortalProfile.fromJson(_map(data['profile']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<PortalProfile> updateProfile({
    required PortalProfileUpdateInput input,
    required String idempotencyKey,
  }) async {
    final data = await _client.requestData(
      'PATCH',
      'me',
      body: input.toJson(),
      idempotencyKey: idempotencyKey,
    );
    try {
      return PortalProfile.fromJson(_map(data['profile']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw const FormatException('Expected object');
  }

  static ApiFailure _invalidResponse() {
    return const ApiFailure(
      code: 'API_RESPONSE_INVALID',
      message: 'Dữ liệu trả về chưa hợp lệ.',
    );
  }
}
