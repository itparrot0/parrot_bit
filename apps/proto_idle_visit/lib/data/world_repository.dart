import 'dart:convert';
import 'dart:math';

import 'package:core_storage/core_storage.dart';

import '../domain/domain.dart';

/// 세계 상태를 key-value 저장소에 JSON 한 덩어리로 저장한다.
///
/// 키 이름과 스키마는 이 앱이 소유한다 (`core_storage`는 도메인을 모른다).
final class WorldRepository {
  WorldRepository(this._store, {Catalog? catalog, Random? seedSource})
    : catalog = catalog ?? Catalog.standard,
      _seedSource = seedSource ?? Random();

  static const String worldKey = 'proto_idle_visit.world';
  static const String clockOffsetKey = 'proto_idle_visit.clock_offset_ms';

  final KeyValueStore _store;
  final Random _seedSource;
  final Catalog catalog;

  /// 저장된 세계를 [now]까지 진행해서 돌려준다. 저장본이 없거나 읽을 수 없으면
  /// 새 세계를 만든다 — 프로토타입이라 깨진 저장본은 버린다.
  ///
  /// 오프라인 동안 도착한 손님은 [LoadedWorld.arrivals]에 담긴다.
  Future<LoadedWorld> load(DateTime now) async {
    final raw = await _store.getString(worldKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, Object?>;
        final world = World.fromJson(json, catalog: catalog);
        final arrivals = world.advance(now);
        return LoadedWorld(world, arrivals);
      } on Object {
        // 아래로 떨어져 새로 시작한다.
      }
    }
    final world = World(
      catalog: catalog,
      seed: _seedSource.nextInt(1 << 31),
      now: now,
    );
    return LoadedWorld(world, const []);
  }

  Future<void> save(World world) =>
      _store.setString(worldKey, jsonEncode(world.toJson()));

  /// 개발용 "빨리 감기"로 앞당긴 시간. 저장해 두지 않으면 재시작할 때 시계가
  /// 뒤로 가서 세계가 멈춘 것처럼 보인다.
  Future<Duration> loadClockOffset() async =>
      Duration(milliseconds: await _store.getInt(clockOffsetKey) ?? 0);

  Future<void> saveClockOffset(Duration offset) =>
      _store.setInt(clockOffsetKey, offset.inMilliseconds);
}

final class LoadedWorld {
  const LoadedWorld(this.world, this.arrivals);

  final World world;

  /// 앱이 꺼져 있던 동안 도착한 손님들.
  final List<Arrival> arrivals;
}
