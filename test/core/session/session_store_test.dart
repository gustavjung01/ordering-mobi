import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/session/session_store.dart';

class _MemorySecureStringStore implements SecureStringStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('secure Clerk persistor round-trips structured session state', () async {
    final storage = _MemorySecureStringStore();
    final store = SecureSessionStore(storage: storage);
    final value = <String, dynamic>{
      'id': 'client_1',
      'sessions': <dynamic>[
        <String, dynamic>{'id': 'session_1'},
      ],
    };

    await store.initialize();
    await store.write('client', value);

    expect(await store.read<Map<String, dynamic>>('client'), value);
    expect(storage.values.keys.single, 'ordering.clerk.client');

    await store.delete('client');
    expect(await store.read<Map<String, dynamic>>('client'), isNull);
  });
}
