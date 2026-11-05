import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_log/data/settings_repository.dart';
import 'package:sleep_log/domain/domain.dart';

void main() {
  test('설정한 적이 없으면 null — 기본값으로 채우지 않는다', () async {
    final repository = SettingsRepository(InMemoryKeyValueStore());

    expect(await repository.loadTarget(), isNull);
  });

  test('저장한 목표를 그대로 읽는다', () async {
    final repository = SettingsRepository(InMemoryKeyValueStore());
    final target = SleepTarget(const Duration(hours: 8, minutes: 30));

    await repository.saveTarget(target);

    expect(await repository.loadTarget(), target);
  });

  test('허용 범위를 벗어난 저장값은 설정하지 않은 것으로 본다', () async {
    final repository = SettingsRepository(
      InMemoryKeyValueStore({SettingsRepository.targetMinutesKey: 30}),
    );

    expect(await repository.loadTarget(), isNull);
  });
}
