import 'package:clerk_flutter/clerk_flutter.dart';

import 'customer_auth_client.dart';

class ClerkCustomerAuthClient implements CustomerAuthClient {
  const ClerkCustomerAuthClient(this._authState);

  final ClerkAuthState _authState;

  @override
  Future<CustomerAuthSession?> currentSession() async {
    final userId = _authState.user?.id.trim();
    if (userId == null || userId.isEmpty) return null;
    return CustomerAuthSession(userId: userId);
  }

  @override
  Future<String?> getToken() async {
    if (!_authState.isSignedIn) return null;
    try {
      final token = await _authState.sessionToken();
      final jwt = token.jwt.trim();
      return jwt.isEmpty ? null : jwt;
    } on Object {
      return null;
    }
  }

  @override
  Future<CustomerAuthSession?> refresh() async {
    try {
      await _authState.refreshClient();
      if (_authState.isSignedIn) {
        await _authState.sessionToken();
      }
    } on Object {
      return null;
    }
    return currentSession();
  }

  @override
  Future<void> signOut() => _authState.signOut();
}
