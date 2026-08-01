import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('타입별 저장/조회가 동작한다', () async {
      final store = InMemoryKeyValueStore();

      await store.setString('name', 'parrot');
      await store.setBool('flag', true);
      await store.setInt('count', 3);
      await store.setDouble('ratio', 0.5);

      expect(await store.getString('name'), 'parrot');
      expect(await store.getBool('flag'), isTrue);
      expect(await store.getInt('count'), 3);
      expect(await store.getDouble('ratio'), 0.5);
    });

    test('없는 키는 null을 반환한다', () async {
      final store = InMemoryKeyValueStore();

      expect(await store.getString('missing'), isNull);
      expect(await store.containsKey('missing'), isFalse);
    });

    test('remove 후 키가 사라진다', () async {
      final store = InMemoryKeyValueStore({'key': 'value'});

      expect(await store.containsKey('key'), isTrue);
      await store.remove('key');
      expect(await store.containsKey('key'), isFalse);
    });
  });
}
