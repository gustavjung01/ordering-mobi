class OrderingRuntimeConfig {
  const OrderingRuntimeConfig({
    required this.clerkPublishableKey,
    required this.customerPortalOrigin,
  });

  const OrderingRuntimeConfig.fromEnvironment()
    : clerkPublishableKey = const String.fromEnvironment(
        'ORDERING_CLERK_PUBLISHABLE_KEY',
      ),
      customerPortalOrigin = const String.fromEnvironment(
        'ORDERING_CUSTOMER_PORTAL_ORIGIN',
      );

  final String clerkPublishableKey;
  final String customerPortalOrigin;

  bool get hasValidClerkPublishableKey {
    final key = clerkPublishableKey.trim();
    return key.startsWith('pk_test_') || key.startsWith('pk_live_');
  }

  Uri? get customerPortalBaseUri {
    final raw = customerPortalOrigin.trim();
    final origin = Uri.tryParse(raw);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.query.isNotEmpty ||
        origin.fragment.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      return null;
    }

    return origin.replace(path: '/api/customer-portal/');
  }

  bool get isReady =>
      hasValidClerkPublishableKey && customerPortalBaseUri != null;
}
