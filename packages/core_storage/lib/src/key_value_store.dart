/// key-value 저장소 추상 인터페이스.
///
/// 조회는 값이 없으면 null을 반환하고, 저장/삭제 실패는
/// [StorageException]으로 던진다.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);

  Future<bool?> getBool(String key);

  Future<int?> getInt(String key);

  Future<double?> getDouble(String key);

  Future<void> setString(String key, String value);

  Future<void> setBool(String key, bool value);

  Future<void> setInt(String key, int value);

  Future<void> setDouble(String key, double value);

  Future<void> remove(String key);

  Future<bool> containsKey(String key);
}
