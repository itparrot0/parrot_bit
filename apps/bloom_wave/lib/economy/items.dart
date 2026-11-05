// 플레이 아이템과 x2 속도 (2026-11-04). 조절 지점은 이 파일 한 곳.
//
// 아이템 3종 — 게임 화면 하단 아이템 칸에 늘 떠 있고, 쓸 때마다 1개씩 줄어든다.
//  1. 슬롯 추가: 이번 판 활성 슬롯 1칸 추가 (최대 [maxSlots]칸)
//  2. 섞기: 대기열 남은 물방울(맨 앞 포함)을 모든 줄에 걸쳐 무작위로 섞는다 (줄마다 개수는 그대로).
//           섞은 뒤에도 완성할 수 있는 배치만 쓴다 (솔버 확인). 못 찾으면 쓰지 않고 개수도 그대로.
//  3. 즉시 개화: 퍼질 곳이 없어 슬롯에 묶인 물방울 하나를 골라, 다 쓸 때까지 같은 색 칸을 무작위로 바로 피운다.
// 해금: 튜토리얼 스테이지(5) 뒤로 3·4·5 스테이지 간격 = 8 · 12 · 17 스테이지.
// 해금되는 스테이지에서 [itemStartCount]개를 받고, 그 판에서 1개를 꼭 써 보게 해 튜토리얼이 끝나면 2개가 남는다.
//
// x2: 기본 속도는 느린 속도(틱 [baseTickMs]), x2 를 켜면 빠른 속도(틱 [x2TickMs]).
// 켜 둔 동안 웨이브가 실제로 진행될 때만 남은 시간이 줄어든다 (일시정지·안내창·멈춘 판에서는 줄지 않음). 0이 되면 저절로 꺼진다.

enum ItemKind { slot, shuffle, bloom }

class ItemDef {
  const ItemDef(this.kind, this.unlockStage);
  final ItemKind kind;

  /// 이 스테이지에서 해금 + 튜토리얼
  final int unlockStage;

  String get id => kind.name;
}

const List<ItemDef> itemDefs = [
  ItemDef(ItemKind.slot, 8),
  ItemDef(ItemKind.shuffle, 12),
  ItemDef(ItemKind.bloom, 17),
];

ItemDef itemDef(ItemKind k) => itemDefs.firstWhere((d) => d.kind == k);

/// 해금할 때 주는 개수 (튜토리얼에서 1개를 써서 2개가 남는다)
const itemStartCount = 3;

/// 슬롯 추가 아이템으로 늘릴 수 있는 최대 활성 슬롯 수
const maxSlots = 6;

/// 틱 간격(ms): 기본(느림) / x2
const baseTickMs = 450;
const x2TickMs = 300;

/// x2 처음 주는 시간(ms) — 10분
const x2InitialMs = 10 * 60 * 1000;
