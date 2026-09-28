import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OrderingLocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPreferencesOrderingLocalStore implements OrderingLocalStore {
  SharedPreferencesOrderingLocalStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
