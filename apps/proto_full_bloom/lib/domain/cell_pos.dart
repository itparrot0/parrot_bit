/// 격자 좌표. 값 타입이라 Map 키·Set 원소로 그대로 쓴다.
typedef CellPos = ({int col, int row});

/// 이웃을 보는 순서: **하 → 좌 → 우 → 상**.
///
/// 이 순서가 곧 큐에 들어가는 순서이고, 큐 순서가 곧 개화 순서다
/// (docs/prd/full_bloom.md §3.3). 바꾸면 게임이 바뀐다.
const List<CellPos> kNeighborOffsets = [
  (col: 0, row: 1), // 하
  (col: -1, row: 0), // 좌
  (col: 1, row: 0), // 우
  (col: 0, row: -1), // 상
];

/// [pos]의 이웃 4칸을 하→좌→우→상 순서로 낸다. 보드 밖 판정은 호출자가 한다.
Iterable<CellPos> neighborsInOrder(CellPos pos) => kNeighborOffsets.map(
  (offset) => (col: pos.col + offset.col, row: pos.row + offset.row),
);
