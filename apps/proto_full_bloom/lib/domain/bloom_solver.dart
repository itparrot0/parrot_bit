import 'bloom_board.dart';
import 'bloom_level.dart';

/// 솔버 결과. [solution]이 null이면 해를 못 찾은 것이다.
typedef SolveReport = ({
  /// 승리까지의 슬롯 인덱스 수순. null이면 해가 없거나 못 찾았다.
  List<int>? solution,

  /// 방문한 상태 수. 난이도 지표 — 클수록 길을 찾기 어렵다 (PRD §4.4).
  int statesVisited,

  /// 교착으로 끝난 분기 수. 난이도 지표 — 클수록 함정이 많다.
  int deadlockCount,

  /// 탐색 상한에 걸려 포기했는가. true면 [solution] == null이
  /// "해가 없다"가 아니라 "모르겠다"는 뜻이다.
  bool exhausted,
});

/// 레벨이 **교착 없이 끝까지 가는지** 찾는다 (PRD §4.3).
///
/// 탐색이 현실적인 이유: 연쇄가 전자동·결정론적이라 한 수의 결과가 한 가지로
/// 정해지고, 분기가 슬롯 수(보통 3)뿐이다. §3.7 덕에 "물 부족" 판정이 필요
/// 없어 탐색은 교착 회피 하나만 본다.
///
/// [BloomBoard.undo]로 되돌리며 깊이 우선 탐색하므로 보드를 복제하지 않는다.
abstract final class BloomSolver {
  /// 상태 방문 상한. 넘으면 포기하고 `exhausted: true`를 돌려준다.
  static const int defaultMaxStates = 200000;

  static SolveReport solve(
    BloomLevel level, {
    int maxStates = defaultMaxStates,
  }) {
    final board = BloomBoard(level);
    final visited = <String>{};
    final moves = <int>[];
    var statesVisited = 0;
    var deadlockCount = 0;
    var exhausted = false;

    bool search() {
      if (board.isWon) {
        return true;
      }
      if (statesVisited >= maxStates) {
        exhausted = true;
        return false;
      }
      if (!visited.add(board.stateKey)) {
        return false;
      }
      statesVisited++;

      var branched = false;
      for (var index = 0; index < board.slots.length; index++) {
        if (!board.canUseSlot(index)) {
          continue;
        }
        branched = true;
        board.useSlot(index);
        moves.add(index);
        if (search()) {
          return true;
        }
        moves.removeLast();
        board.undo();
        if (exhausted) {
          return false;
        }
      }
      // 쓸 수 있는 슬롯이 없었다 = 교착 (PRD §3.8).
      if (!branched) {
        deadlockCount++;
      }
      return false;
    }

    final solved = search();
    return (
      solution: solved ? List.of(moves) : null,
      statesVisited: statesVisited,
      deadlockCount: deadlockCount,
      exhausted: exhausted,
    );
  }

  /// 해가 있는지만 본다. 생성기가 레벨을 버릴지 결정할 때 쓴다.
  static bool isSolvable(
    BloomLevel level, {
    int maxStates = defaultMaxStates,
  }) => solve(level, maxStates: maxStates).solution != null;
}
