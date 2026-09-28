import 'dart:async';
import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStringStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStringStore implements SecureStringStore {
  FlutterSecureStringStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SecureSessionStore implements clerk.Persistor {
  SecureSessionStore({SecureStringStore? storage})
    : _storage = storage ?? FlutterSecureStringStore();

  static const _keyPrefix = 'ordering.clerk.';

  final SecureStringStore _storage;

  String _key(String key) => '$_keyPrefix$key';

  @override
  Future<void> initialize() async {}

  @override
  void terminate() {}

  @override
  Future<T?> read<T>(String key) async {
    final encoded = await _storage.read(_key(key));
    if (encoded == null) return null;
    return jsonDecode(encoded) as T?;
  }

  @override
  Future<void> write<T>(String key, T value) =>
      _storage.write(_key(key), jsonEncode(value));

  @override
  Future<void> delete(String key) => _storage.delete(_key(key));
}
