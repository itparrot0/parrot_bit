import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';
import 'storage_exception.dart';

/// shared_preferences 기반 구현.
final class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) =>
      _guard(() => _preferences.getString(key));

  @override
  Future<bool?> getBool(String key) => _guard(() => _preferences.getBool(key));

  @override
  Future<int?> getInt(String key) => _guard(() => _preferences.getInt(key));

  @override
  Future<double?> getDouble(String key) =>
      _guard(() => _preferences.getDouble(key));

  @override
  Future<void> setString(String key, String value) =>
      _guard(() => _preferences.setString(key, value));

  @override
  Future<void> setBool(String key, bool value) =>
      _guard(() => _preferences.setBool(key, value));

  @override
  Future<void> setInt(String key, int value) =>
      _guard(() => _preferences.setInt(key, value));

  @override
  Future<void> setDouble(String key, double value) =>
      _guard(() => _preferences.setDouble(key, value));

  @override
  Future<void> remove(String key) => _guard(() => _preferences.remove(key));

  @override
  Future<bool> containsKey(String key) =>
      _guard(() => _preferences.containsKey(key));

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (cause) {
      throw StorageException('storage operation failed', cause);
    }
  }
}
