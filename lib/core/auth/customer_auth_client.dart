class CustomerAuthSession {
  const CustomerAuthSession({required this.userId});

  final String userId;
}

abstract interface class CustomerAuthClient {
  Future<CustomerAuthSession?> currentSession();

  Future<String?> getToken();

  Future<CustomerAuthSession?> refresh();

  Future<void> signOut();
}
