import 'package:flutter/material.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../core/auth/clerk_customer_auth_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_api.dart';
import '../../../core/network/customer_portal_client.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../core/session/session_store.dart';
import '../../../core/storage/ordering_local_store.dart';
import '../../ordering/data/customer_ordering_repository.dart';

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
  CustomerOrderingRepository? _orderingRepository;

  @override
  void initState() {
    super.initState();
    _portalClient = CustomerPortalClient(
      baseUri: widget.baseUri,
      tokenProvider: widget.authClient.getToken,
    );
    _portalApi = CustomerPortalApi(_portalClient);
    _profileFuture = _loadSession();
  }

  @override
  void dispose() {
    _orderingRepository?.dispose();
    _portalClient.close();
    super.dispose();
  }

  Future<CustomerProfile> _loadSession() async {
    final profileFuture = _portalApi.getProfile();
    final sessionFuture = widget.authClient.currentSession();
    final profile = await profileFuture;
    final session = await sessionFuture;
    if (session == null) {
      throw const ApiFailure(
        code: 'AUTH_REQUIRED',
        message: 'Vui lòng đăng nhập lại để tiếp tục.',
        statusCode: 401,
      );
    }

    _orderingRepository?.dispose();
    final repository = CustomerOrderingRepository(
      remote: _portalApi,
      localStore: SharedPreferencesOrderingLocalStore(),
      secureStore: FlutterSecureStringStore(),
      userId: session.userId,
    );
    await repository.initialize();
    _orderingRepository = repository;
    return profile;
  }

  void _retry() {
    setState(() {
      _profileFuture = _loadSession();
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

        if (snapshot.hasData && _orderingRepository != null) {
          return AppShell(
            profile: snapshot.data!,
            repository: _orderingRepository!,
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
