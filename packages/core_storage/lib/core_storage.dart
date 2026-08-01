/// key-value 로컬 저장의 추상 인터페이스와 구현.
///
/// 무엇을 저장할지(키 이름, 스키마)는 각 앱이 정의한다.
/// 앱은 [SharedPrefsKeyValueStore], 테스트는 [InMemoryKeyValueStore]를 쓴다.
library;

export 'src/in_memory_key_value_store.dart';
export 'src/key_value_store.dart';
export 'src/shared_prefs_key_value_store.dart';
export 'src/storage_exception.dart';
