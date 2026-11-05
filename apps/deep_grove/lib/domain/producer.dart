import 'item.dart';

/// 산출원: 체인 최고 레벨에 닿은 조각 (테마 문서 §4).
///
/// 소멸하지 않고 칸을 영구 점유하며, 시간이 지나면 [stock]에 자원이 쌓인다.
/// 탭하면 쌓인 것 중 정수 부분을 창고로 보낸다. 드래그로 옮기고 자리 교체는
/// 되지만 머지는 되지 않는다. [stock]은 조각과 함께 움직이므로 조각 안에 둔다.
final class Producer {
  Producer(this.chain, {this.stock = 0});

  final ItemChain chain;

  /// 아직 창고로 보내지 않은 산출량 (소수 포함 — 산출은 연속으로 쌓인다).
  double stock;

  /// 지금 거둘 수 있는 양.
  int get ripe => stock.floor();

  @override
  String toString() => 'Producer(${chain.id} stock:$stock)';
}
