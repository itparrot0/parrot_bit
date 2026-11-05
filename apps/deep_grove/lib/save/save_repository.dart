import 'dart:math';
import 'dart:convert';

import 'package:core_storage/core_storage.dart';

import '../domain/board_model.dart';
import '../economy/ad_rewards.dart';
import '../economy/economy.dart';

/// 저장 한 벌: 보드(인게임) + 창고(아웃게임) + 저장 시각.
final class GroveSave {
  const GroveSave({
    required this.board,
    required this.economy,
    required this.savedAt,
    this.ads = const AdRewards(),
  });

  final BoardModel board;
  final Economy economy;
  final AdRewards ads;
  final DateTime savedAt;
}

/// 불러온 결과. 오프라인 동안의 방치 산출은 이미 [board]에 쌓여 있다.
final class LoadedGrove {
  const LoadedGrove({
    required this.board,
    required this.economy,
    required this.idleGain,
    required this.isNew,
    this.ads = const AdRewards(),
  });

  final BoardModel board;
  final Economy economy;
  final AdRewards ads;

  /// 자리를 비운 동안 쌓인 양 (자원별, 정수). 비어 있으면 복귀 보상을 띄우지 않는다.
  final Map<Resource, int> idleGain;

  /// 저장이 없어서(또는 깨져서) 새로 시작했는가.
  final bool isNew;
}

/// `core_storage` key-value 에 JSON 스냅샷 하나로 저장한다 (PRD §8.1).
///
/// 보드는 칸 수십 개라 통째로 써도 싸다 — 매 조작마다 저장한다.
final class SaveRepository {
  SaveRepository(this._store);

  static const String key = 'deep_grove.save';
  static const int schema = 1;

  final KeyValueStore _store;

  Future<void> write(GroveSave save) => _store.setString(
    key,
    jsonEncode({
      'schema': schema,
      'savedAt': save.savedAt.millisecondsSinceEpoch,
      'board': save.board.toJson(),
      'economy': save.economy.toJson(),
      'ads': save.ads.toJson(),
    }),
  );

  /// 저장을 읽어 오프라인 산출을 반영한다. 저장이 없거나 깨졌으면 새 보드.
  ///
  /// 경과 시간은 기기 시계 기준이다. 시계를 되돌려 음수가 되면 0으로 본다
  /// (PRD §8.2). 앞당기는 조작은 창고 용량이 상한이라 따로 막지 않는다.
  Future<LoadedGrove> load(
    GroveTheme theme, {
    required DateTime now,
    Random? random,
  }) async {
    final raw = await _store.getString(key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, Object?>;
        if (json['schema'] == schema) {
          final board = BoardModel.fromJson(
            json['board']! as Map<String, Object?>,
            theme,
            random: random,
          );
          final economy = Economy.fromJson(
            json['economy']! as Map<String, Object?>,
            theme,
          );
          final savedAt = DateTime.fromMillisecondsSinceEpoch(
            json['savedAt']! as int,
          );
          // 'ads'는 나중에 더한 칸이라 없을 수 있다 — 없으면 빈 기록.
          final ads = AdRewards.fromJson(json['ads']);
          final idleGain = ads.advanceAway(
            board,
            savedAt,
            now,
            economy.freeSpace,
          );
          return LoadedGrove(
            board: board,
            economy: economy,
            ads: ads,
            idleGain: idleGain,
            isNew: false,
          );
        }
      } on FormatException {
        // 깨진 저장은 새로 시작한다. 아래로 내려간다.
      } on TypeError {
        // 위와 같다.
      }
    }
    return LoadedGrove(
      board: BoardModel(theme, random: random),
      economy: Economy(theme: theme),
      idleGain: const {},
      isNew: true,
    );
  }
}
