import '../domain/board_model.dart';
import 'economy.dart';

/// 첫 실행 손가락 안내 두 개 (화면 흐름 §5). 튜토리얼 화면은 없다.
enum Hint {
  /// 생성기를 한 번 눌러 보게 한다. 첫 생성에 성공하면 끝.
  tapGenerator('tap_generator'),

  /// 처음으로 확장할 자원이 모였을 때 손잡이를 가리킨다. 첫 확장을 하면 끝.
  firstExpand('first_expand');

  const Hint(this.id);

  final String id;
}

/// 손가락이 가리킬 곳: 보드 칸 하나 또는 확장 손잡이 하나.
sealed class HintTarget {
  const HintTarget(this.hint);

  final Hint hint;
}

final class CellHint extends HintTarget {
  const CellHint(super.hint, this.pos);

  final CellPos pos;

  @override
  bool operator ==(Object other) =>
      other is CellHint && other.hint == hint && other.pos == pos;

  @override
  int get hashCode => Object.hash(hint, pos);
}

final class HandleHint extends HintTarget {
  const HandleHint(super.hint, this.direction);

  final ExpandDirection direction;

  @override
  bool operator ==(Object other) =>
      other is HandleHint && other.hint == hint && other.direction == direction;

  @override
  int get hashCode => Object.hash(hint, direction);
}

/// 끝낸 안내 목록. 불변 값.
final class Hints {
  const Hints([this.done = const {}]);

  final Set<Hint> done;

  bool isDone(Hint h) => done.contains(h);

  Hints complete(Hint h) => isDone(h) ? this : Hints({...done, h});

  /// 지금 띄울 안내. 한 번에 하나, 순서대로.
  HintTarget? active(BoardModel board, Economy economy) {
    if (!isDone(Hint.tapGenerator)) {
      for (final (pos, content) in _sorted(board)) {
        if (content is GeneratorContent) {
          return CellHint(Hint.tapGenerator, pos);
        }
      }
      return null;
    }
    if (!isDone(Hint.firstExpand)) {
      // 넓히기를 먼저 권한다 (첫 비용이 가장 싸다).
      for (final d in [ExpandDirection.widen, ExpandDirection.dig]) {
        final cost = economy.expansionCost(d, board);
        if (cost != null && economy.canAfford(cost)) {
          return HandleHint(Hint.firstExpand, d);
        }
      }
    }
    return null;
  }

  static List<(CellPos, CellContent)> _sorted(BoardModel board) =>
      board.cells.entries.map((e) => (e.key, e.value)).toList()..sort(
        (a, b) =>
            a.$1.row != b.$1.row ? a.$1.row - b.$1.row : a.$1.col - b.$1.col,
      );

  List<String> toJson() => [for (final h in done) h.id];

  /// 저장에 안내 칸이 없으면(안내를 만들기 전 저장) 보드를 보고 짐작한다 —
  /// 이미 놀던 사람에게 첫 안내를 띄우지 않는다.
  static Hints fromJson(Object? json, BoardModel board, GroveTheme theme) {
    if (json case final List<Object?> ids) {
      return Hints({
        for (final h in Hint.values)
          if (ids.contains(h.id)) h,
      });
    }
    final expanded = board.columns > theme.startColumns || board.caveRows > 0;
    final played = expanded || board.mergeCount > 0 || board.cells.length > 3;
    return Hints({
      if (played) Hint.tapGenerator,
      if (expanded) Hint.firstExpand,
    });
  }
}
