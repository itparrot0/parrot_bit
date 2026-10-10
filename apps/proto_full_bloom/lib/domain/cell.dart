import 'bloom_color.dart';

/// 칸의 3단계 (기획서 §3).
enum CellStage {
  /// 씨앗 🌱 — 아직 물을 줄 수 없다. 주변 꽃의 개화로 발아한다.
  seed,

  /// 발아 🌿 — **물을 받을 수 있는 유일한 상태.**
  /// 큐에 들어 있는 칸이 정확히 이 상태다.
  sprout,

  /// 개화 🌸 — 물을 다시 받지 않는다. 주변 씨앗을 발아시킨다.
  bloomed,
}

/// 보드 한 칸. 색은 3단계를 지나도 변하지 않는다.
final class Cell {
  const Cell({required this.color, required this.stage});

  const Cell.seed(this.color) : stage = CellStage.seed;

  const Cell.sprout(this.color) : stage = CellStage.sprout;

  final BloomColor color;
  final CellStage stage;

  bool get isSeed => stage == CellStage.seed;

  bool get isSprout => stage == CellStage.sprout;

  bool get isBloomed => stage == CellStage.bloomed;

  /// 씨앗 → 발아. 이 전이는 칸마다 **한 번뿐이고**, 그래서 큐 중복 삽입이
  /// 구조적으로 막힌다 (기획서 §43-2의 답).
  Cell get sprouted => Cell(color: color, stage: CellStage.sprout);

  Cell get bloomedCell => Cell(color: color, stage: CellStage.bloomed);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.color == color && other.stage == stage;

  @override
  int get hashCode => Object.hash(color, stage);

  @override
  String toString() => 'Cell(${color.name}, ${stage.name})';
}
