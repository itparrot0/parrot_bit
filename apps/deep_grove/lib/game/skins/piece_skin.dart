import 'package:flame/components.dart';

/// 보드 조각의 시각 상태. 상태가 바뀌면 [PieceSkin]이 만든 생김새로 통째로 교체된다.
enum PieceVisualState {
  /// 보드에 놓여 있는 평소 모습.
  resting,

  /// 손가락에 붙어 끌려다니는 중 (핸들링).
  dragging,
}

/// 보드 조각 하나의 생김새 정의.
///
/// "이 조각이 무엇인가"(종류·체인·레벨)는 스킨을 고르는 쪽이 이미 판단했고,
/// 스킨은 **상태별로 그릴 컴포넌트만** 만든다. 그래서 텍스트 프로토타입 →
/// 이미지 전환이 구현체 교체 하나로 끝난다.
abstract interface class PieceSkin {
  /// [state]에서 보여줄 생김새.
  ///
  /// 상태가 바뀔 때마다 새로 호출되므로 매번 새 컴포넌트를 반환해야 한다
  /// (이전 것은 호출한 쪽이 트리에서 제거한다).
  Component build(PieceVisualState state, Vector2 size);
}
