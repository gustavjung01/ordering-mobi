import 'package:flutter/material.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../core/auth/clerk_customer_auth_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_api.dart';
import '../../../core/network/customer_portal_client.dart';
import '../../../core/network/customer_portal_models.dart';

class CustomerPortalSessionGate extends StatefulWidget {
  const CustomerPortalSessionGate({
    super.key,
    required this.authClient,
    required this.baseUri,
  });

  final ClerkCustomerAuthClient authClient;
  final Uri baseUri;

  @override
  State<CustomerPortalSessionGate> createState() =>
      _CustomerPortalSessionGateState();
}

class _CustomerPortalSessionGateState extends State<CustomerPortalSessionGate> {
  late final CustomerPortalClient _portalClient;
  late final CustomerPortalApi _portalApi;
  late Future<CustomerProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _portalClient = CustomerPortalClient(
      baseUri: widget.baseUri,
      tokenProvider: widget.authClient.getToken,
    );
    _portalApi = CustomerPortalApi(_portalClient);
    _profileFuture = _portalApi.getProfile();
  }

  @override
  void dispose() {
    _portalClient.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _profileFuture = _portalApi.getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasData) {
          return AppShell(
            customerDisplayName: snapshot.data!.displayName,
            onSignOut: widget.authClient.signOut,
          );
        }

        final error = snapshot.error;
        final message = error is ApiFailure
            ? error.message
            : 'Không tải được thông tin tài khoản. Vui lòng thử lại.';
        return Scaffold(
          appBar: AppBar(title: const Text('Tài khoản khách hàng')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Thử lại'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: widget.authClient.signOut,
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
