import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/auth/clerk_customer_auth_client.dart';
import 'customer_portal_session_gate.dart';
import 'sign_in_screen.dart';

class CustomerAuthGate extends StatelessWidget {
  const CustomerAuthGate({
    super.key,
    required this.customerPortalBaseUri,
    this.assistantEndpoint,
  });

  final Uri customerPortalBaseUri;
  final Uri? assistantEndpoint;

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) {
        final authClient = ClerkCustomerAuthClient(authState);
        return CustomerPortalSessionGate(
          authClient: authClient,
          baseUri: customerPortalBaseUri,
          assistantEndpoint: assistantEndpoint,
        );
      },
      signedOutBuilder: (context, authState) {
        return CustomerSignInScreen(
          authClient: ClerkCustomerAuthClient(authState),
        );
      },
    );
  }
}
