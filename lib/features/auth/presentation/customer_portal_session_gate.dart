import 'package:flutter/material.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../core/auth/clerk_customer_auth_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_account_api.dart';
import '../../../core/network/customer_portal_account_models.dart';
import '../../../core/network/customer_portal_api.dart';
import '../../../core/network/customer_portal_client.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../core/session/session_store.dart';
import '../../../core/storage/catalog_local_store.dart';
import '../../../core/storage/ordering_local_store.dart';
import '../../account/data/customer_account_repository.dart';
import '../../assistant/data/customer_assistant_api.dart';
import '../../ordering/data/customer_ordering_repository.dart';

class CustomerPortalSessionGate extends StatefulWidget {
  const CustomerPortalSessionGate({
    super.key,
    required this.authClient,
    required this.baseUri,
    this.assistantEndpoint,
    this.accountImageUrl,
  });

  final ClerkCustomerAuthClient authClient;
  final Uri baseUri;
  final Uri? assistantEndpoint;
  final String? accountImageUrl;

  @override
  State<CustomerPortalSessionGate> createState() =>
      _CustomerPortalSessionGateState();
}

class _CustomerPortalSessionGateState extends State<CustomerPortalSessionGate> {
  late final CustomerPortalClient _portalClient;
  late final CustomerPortalApi _portalApi;
  late final CustomerPortalAccountApi _accountApi;
  CustomerAssistantApi? _assistantApi;
  late Future<_PortalSessionData> _sessionFuture;
  CustomerOrderingRepository? _orderingRepository;
  CustomerAccountRepository? _accountRepository;

  @override
  void initState() {
    super.initState();
    _portalClient = CustomerPortalClient(
      baseUri: widget.baseUri,
      tokenProvider: widget.authClient.getToken,
    );
    _portalApi = CustomerPortalApi(_portalClient);
    _accountApi = CustomerPortalAccountApi(_portalClient);
    final assistantEndpoint = widget.assistantEndpoint;
    if (assistantEndpoint != null) {
      _assistantApi = CustomerAssistantApi(
        endpoint: assistantEndpoint,
        tokenProvider: widget.authClient.getToken,
      );
    }
    _sessionFuture = _loadSession();
  }

  @override
  void dispose() {
    _orderingRepository?.dispose();
    _assistantApi?.close();
    _portalClient.close();
    super.dispose();
  }

  Future<_PortalSessionData> _loadSession() async {
    final session = await widget.authClient.currentSession();
    if (session == null) {
      throw const ApiFailure(
        code: 'AUTH_REQUIRED',
        message: 'Vui lòng đăng nhập lại để tiếp tục.',
        statusCode: 401,
      );
    }

    _orderingRepository?.dispose();
    final orderingRepository = CustomerOrderingRepository(
      _portalApi,
      SharedPreferencesOrderingLocalStore(),
      FlutterSecureStringStore(),
      userId: session.userId,
      catalogStore: SqliteCustomerCatalogStore(),
    );
    final accountRepository = CustomerAccountRepository(
      _accountApi,
      FlutterSecureStringStore(),
      userId: session.userId,
    );

    await orderingRepository.initialize();
    final lifecycle = await accountRepository.getLifecycle();
    CustomerProfile? profile;
    if (lifecycle.isActiveCustomer) {
      profile = await _portalApi.getProfile();
    }

    _orderingRepository = orderingRepository;
    _accountRepository = accountRepository;
    return _PortalSessionData(
      lifecycle: lifecycle,
      profile: profile,
    );
  }

  void _retry() {
    setState(() {
      _sessionFuture = _loadSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PortalSessionData>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasData &&
            _orderingRepository != null &&
            _accountRepository != null) {
          return AppShell(
            lifecycle: snapshot.data!.lifecycle,
            profile: snapshot.data!.profile,
            orderingRepository: _orderingRepository!,
            accountRepository: _accountRepository!,
            assistantApi: _assistantApi,
            customerDisplayName: snapshot.data!.profile?.displayName,
            accountImageUrl: widget.accountImageUrl,
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

class _PortalSessionData {
  const _PortalSessionData({
    required this.lifecycle,
    required this.profile,
  });

  final PortalLifecycleSnapshot lifecycle;
  final CustomerProfile? profile;
}
