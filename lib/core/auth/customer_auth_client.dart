class CustomerAuthSession {
  const CustomerAuthSession({required this.userId});

  final String userId;
}

class CustomerAuthFailure implements Exception {
  const CustomerAuthFailure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'CustomerAuthFailure($code)';
}

abstract interface class CustomerAuthClient {
  Future<CustomerAuthSession> signIn({
    required String identifier,
    required String password,
  });

  Future<CustomerAuthSession?> currentSession();

  Future<String?> getToken();

  Future<CustomerAuthSession?> refresh();

  Future<void> signOut();
}
