import 'bloom_color.dart';

/// 칸의 3단계 (PRD §3.1).
enum CellStage {
  /// 잠들어 있다. 물을 받을 수 없고, 이웃이 개화해야 깨어난다.
  seed,

  /// 물을 받을 수 있다. **큐에 들어 있는 칸이 정확히 이 상태다.**
  bud,

  /// 다 피었다. 더 이상 변하지 않는다.
  bloomed,
}

/// 보드 한 칸. 색은 3단계를 지나도 변하지 않는다.
final class Cell {
  const Cell({required this.color, required this.stage});

  const Cell.seed(this.color) : stage = CellStage.seed;

  const Cell.bud(this.color) : stage = CellStage.bud;

  final BloomColor color;
  final CellStage stage;

  bool get isSeed => stage == CellStage.seed;

  bool get isBud => stage == CellStage.bud;

  bool get isBloomed => stage == CellStage.bloomed;

  Cell get awakened => Cell(color: color, stage: CellStage.bud);

  Cell get bloomedCell => Cell(color: color, stage: CellStage.bloomed);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.color == color && other.stage == stage;

  @override
  int get hashCode => Object.hash(color, stage);

  @override
  String toString() => 'Cell(${color.name}, ${stage.name})';
}
