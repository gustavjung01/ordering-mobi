import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../core/config/runtime_config.dart';
import '../core/session/session_store.dart';
import '../features/auth/presentation/customer_auth_gate.dart';
import 'theme/app_theme.dart';

class OrderingApp extends StatelessWidget {
  const OrderingApp({
    super.key,
    this.runtimeConfig = const OrderingRuntimeConfig.fromEnvironment(),
  });

  final OrderingRuntimeConfig runtimeConfig;

  @override
  Widget build(BuildContext context) {
    final customerPortalBaseUri = runtimeConfig.customerPortalBaseUri;
    final app = MaterialApp(
      title: 'Hưng Phát Đặt Hàng',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: runtimeConfig.isReady && customerPortalBaseUri != null
          ? CustomerAuthGate(
              customerPortalBaseUri: customerPortalBaseUri,
            )
          : const _ConfigurationRequiredScreen(),
    );

    if (!runtimeConfig.isReady) return app;

    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: runtimeConfig.clerkPublishableKey.trim(),
        persistor: SecureSessionStore(),
      ),
      child: app,
    );
  }
}

class _ConfigurationRequiredScreen extends StatelessWidget {
  const _ConfigurationRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hưng Phát Đặt Hàng')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ứng dụng chưa được cấu hình đăng nhập. '
              'Vui lòng liên hệ bộ phận phụ trách.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
