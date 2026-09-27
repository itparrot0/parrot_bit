import 'key_value_store.dart';

/// 메모리 기반 구현. 테스트 및 프로토타입에서 사용한다.
final class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, Object>? initial])
    : _values = {...?initial};

  final Map<String, Object> _values;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
}
