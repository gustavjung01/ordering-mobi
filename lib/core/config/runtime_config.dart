class OrderingRuntimeConfig {
  static const defaultClerkPublishableKey =
      'pk_live_Y2xlcmsubmd1eWVubGlldWh1bmdwaGF0LmNvbSQ';
  static const defaultCustomerPortalOrigin = 'https://40.233.83.234';
  static const defaultAssistantOrigin = 'https://sales.nguyenlieuhungphat.com';

  const OrderingRuntimeConfig({
    required this.clerkPublishableKey,
    required this.customerPortalOrigin,
    this.assistantOrigin = defaultAssistantOrigin,
  });

  const OrderingRuntimeConfig.fromEnvironment()
    : clerkPublishableKey = const String.fromEnvironment(
        'ORDERING_CLERK_PUBLISHABLE_KEY',
        defaultValue: defaultClerkPublishableKey,
      ),
      customerPortalOrigin = const String.fromEnvironment(
        'ORDERING_CUSTOMER_PORTAL_ORIGIN',
        defaultValue: defaultCustomerPortalOrigin,
      ),
      assistantOrigin = const String.fromEnvironment(
        'ORDERING_ASSISTANT_ORIGIN',
        defaultValue: defaultAssistantOrigin,
      );

  final String clerkPublishableKey;
  final String customerPortalOrigin;
  final String assistantOrigin;

  bool get hasValidClerkPublishableKey {
    final key = clerkPublishableKey.trim();
    return key.startsWith('pk_test_') || key.startsWith('pk_live_');
  }

  Uri? get customerPortalBaseUri {
    final origin = _httpsOrigin(customerPortalOrigin);
    return origin?.replace(path: '/api/customer-portal/');
  }

  Uri? get assistantEndpoint {
    final origin = _httpsOrigin(assistantOrigin);
    return origin?.replace(path: '/api/assistant/chat');
  }

  bool get isReady =>
      hasValidClerkPublishableKey && customerPortalBaseUri != null;
}

Uri? _httpsOrigin(String value) {
  final origin = Uri.tryParse(value.trim());
  if (origin == null ||
      origin.scheme != 'https' ||
      origin.host.isEmpty ||
      origin.userInfo.isNotEmpty ||
      origin.query.isNotEmpty ||
      origin.fragment.isNotEmpty ||
      (origin.path.isNotEmpty && origin.path != '/')) {
    return null;
  }
  return origin.replace(path: '');
}
