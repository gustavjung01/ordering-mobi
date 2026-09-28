import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/config/runtime_config.dart';

void main() {
  test('builds the same-origin Customer Portal BFF base URI', () {
    const config = OrderingRuntimeConfig(
      clerkPublishableKey: 'pk_test_example',
      customerPortalOrigin: 'https://ordering.example',
    );

    expect(config.isReady, isTrue);
    expect(
      config.customerPortalBaseUri.toString(),
      'https://ordering.example/api/customer-portal/',
    );
  });

  test('rejects non-https or path-bearing Customer Portal origins', () {
    const httpConfig = OrderingRuntimeConfig(
      clerkPublishableKey: 'pk_live_example',
      customerPortalOrigin: 'http://ordering.example',
    );
    const pathConfig = OrderingRuntimeConfig(
      clerkPublishableKey: 'pk_live_example',
      customerPortalOrigin: 'https://ordering.example/private',
    );

    expect(httpConfig.isReady, isFalse);
    expect(pathConfig.isReady, isFalse);
  });
}
