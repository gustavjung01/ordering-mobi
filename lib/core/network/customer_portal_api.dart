import 'api_failure.dart';
import 'customer_portal_client.dart';
import 'customer_portal_models.dart';

class CustomerPortalApi {
  const CustomerPortalApi(this._client);

  final CustomerPortalClient _client;

  Future<CustomerProfile> getProfile() async {
    final data = await _client.requestData('GET', 'me');
    try {
      return CustomerProfile.fromJson(_map(data['profile']));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<CustomerCatalogPage> listCatalog({
    int limit = 50,
    int offset = 0,
    String? search,
    String? categoryId,
    String? purchaseMode,
    bool includeCategories = true,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final safeOffset = offset < 0 ? 0 : offset;
    final parameters = <String, String>{
      'limit': '$safeLimit',
      'offset': '$safeOffset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (categoryId?.trim().isNotEmpty == true)
        'categoryId': categoryId!.trim(),
      if (purchaseMode?.trim().isNotEmpty == true)
        'purchaseMode': purchaseMode!.trim(),
      if (includeCategories) 'includeCategories': '1',
    };
    final query = Uri(queryParameters: parameters).query;
    final data = await _client.requestData('GET', 'catalog?$query');
    try {
      return CustomerCatalogPage.fromJson(data);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<List<DeliveryAddress>> listDeliveryAddresses() async {
    final data = await _client.requestData('GET', 'addresses');
    final addresses = data['addresses'];
    if (addresses is! List) throw _invalidResponse();

    try {
      return addresses
          .map((item) => DeliveryAddress.fromJson(_map(item)))
          .toList(growable: false);
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
