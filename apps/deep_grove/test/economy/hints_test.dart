import 'package:deep_grove/domain/board_model.dart';
import 'package:deep_grove/economy/economy.dart';
import 'package:deep_grove/economy/hints.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const theme = forestCaveTheme;

  test('처음에는 생성기를 가리킨다', () {
    final board = BoardModel(theme);
    expect(
      const Hints().active(board, const Economy(theme: theme)),
      const CellHint(Hint.tapGenerator, (col: 1, row: 3)),
    );
  });

  test('생성기를 옮기면 손가락도 따라간다', () {
    final board = BoardModel(theme)..tryMove(at(1, 3), at(2, 0));
    expect(
      const Hints().active(board, const Economy(theme: theme)),
      const CellHint(Hint.tapGenerator, (col: 2, row: 0)),
    );
  });

  test('생성 안내가 끝나면 확장할 자원이 모일 때까지 아무것도 띄우지 않는다', () {
    final hints = const Hints().complete(Hint.tapGenerator);
    final board = BoardModel(theme);
    expect(hints.active(board, const Economy(theme: theme)), isNull);
    expect(
      hints.active(
        board,
        const Economy(theme: theme, amounts: {Resource.wood: 5}),
      ),
      const HandleHint(Hint.firstExpand, ExpandDirection.widen),
    );
  });

  test('넓히기는 못 하고 파기만 할 수 있으면 파기 손잡이를 가리킨다', () {
    final hints = const Hints().complete(Hint.tapGenerator);
    final board = BoardModel(theme)
      ..widen()
      ..widen()
      ..widen();
    expect(
      hints.active(
        board,
        const Economy(theme: theme, amounts: {Resource.wood: 12}),
      ),
      const HandleHint(Hint.firstExpand, ExpandDirection.dig),
    );
  });

  test('두 안내를 다 끝내면 다시 띄우지 않는다', () {
    final hints = const Hints()
        .complete(Hint.tapGenerator)
        .complete(Hint.firstExpand);
    expect(
      hints.active(
        BoardModel(theme),
        const Economy(theme: theme, amounts: {Resource.wood: 30}),
      ),
      isNull,
    );
  });

  test('저장 왕복, 안내 칸이 없는 옛 저장은 보드로 짐작한다', () {
    final hints = const Hints().complete(Hint.tapGenerator);
    expect(Hints.fromJson(hints.toJson(), BoardModel(theme), theme).done, {
      Hint.tapGenerator,
    });
    // 갓 시작한 보드 → 둘 다 안 끝남
    expect(Hints.fromJson(null, BoardModel(theme), theme).done, isEmpty);
    // 생성기를 눌러 아이템이 늘어난 보드 → 생성 안내만 끝남
    final played = BoardModel(theme)
      ..placeItem(at(0, 0), const Item(woodChain, 1));
    expect(Hints.fromJson(null, played, theme).done, {Hint.tapGenerator});
    // 확장한 보드 → 둘 다 끝남
    final expanded = BoardModel(theme)..widen();
    expect(Hints.fromJson(null, expanded, theme).done, Hint.values.toSet());
  });
}
