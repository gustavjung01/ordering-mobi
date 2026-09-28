import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';

import 'customer_auth_client.dart';

class ClerkCustomerAuthClient implements CustomerAuthClient {
  const ClerkCustomerAuthClient(this._authState);

  final ClerkAuthState _authState;

  @override
  Future<CustomerAuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty || password.isEmpty) {
      throw const CustomerAuthFailure(
        code: 'AUTH_INPUT_REQUIRED',
        message: 'Vui lòng nhập đầy đủ tài khoản và mật khẩu.',
      );
    }

    try {
      await _authState.attemptSignIn(
        strategy: clerk.Strategy.password,
        identifier: normalizedIdentifier,
        password: password,
      );
    } on Object {
      throw const CustomerAuthFailure(
        code: 'AUTH_SIGN_IN_FAILED',
        message: 'Không đăng nhập được. Vui lòng kiểm tra lại thông tin.',
      );
    }

    final session = await currentSession();
    if (session == null) {
      throw const CustomerAuthFailure(
        code: 'AUTH_VERIFICATION_REQUIRED',
        message: 'Tài khoản cần thêm bước xác minh trước khi tiếp tục.',
      );
    }
    return session;
  }

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
