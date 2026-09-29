import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/config/runtime_config.dart';

void main() {
  test('production defaults match the Customer Ordering PWA origin', () {
    const config = OrderingRuntimeConfig.fromEnvironment();

    expect(config.isReady, isTrue);
    expect(
      config.customerPortalBaseUri.toString(),
      'https://sales.nguyenlieuhungphat.com/api/customer-portal/',
    );
    expect(
      config.assistantEndpoint.toString(),
      'https://sales.nguyenlieuhungphat.com/api/assistant/chat',
    );
    expect(config.hasValidClerkPublishableKey, isTrue);
  });

  test('allows Customer Portal and assistant origins to be overridden', () {
    const config = OrderingRuntimeConfig(
      clerkPublishableKey: 'pk_test_example',
      customerPortalOrigin: 'https://api.example',
      assistantOrigin: 'https://ordering.example',
    );

    expect(config.isReady, isTrue);
    expect(
      config.customerPortalBaseUri.toString(),
      'https://api.example/api/customer-portal/',
    );
    expect(
      config.assistantEndpoint.toString(),
      'https://ordering.example/api/assistant/chat',
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

  test('invalid assistant origin does not block ordering', () {
    const config = OrderingRuntimeConfig(
      clerkPublishableKey: 'pk_live_example',
      customerPortalOrigin: 'https://api.example',
      assistantOrigin: 'http://ordering.example',
    );

    expect(config.isReady, isTrue);
    expect(config.assistantEndpoint, isNull);
  });
}
