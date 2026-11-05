/// 비소모성 IAP 상품 (PRD §6). 결제는 시간을 줄일 뿐 진행(보드 확장)을 대신하지 않는다.
///
/// 출시 전 할 일: Play Console·App Store Connect 에 아래 [id]로 비소모성(관리형) 상품을 만든다.
/// 가격은 스토어가 정하고 상점은 스토어가 알려 준 가격을 그대로 보여 준다.
enum Product {
  /// 창고 확장팩: 자원별 창고 용량 영구 ×1.5 (창고 단계와 곱해진다).
  storagePack('storage_pack', '창고 확장팩', '자원별 창고 용량 영구 1.5배'),

  /// 영구 산출 가속: 산출원 산출량 영구 ×1.5 (광고 가속과 곱해진다).
  outputBoost('output_boost', '영구 산출 가속', '산출원 산출량 영구 1.5배');

  const Product(this.id, this.title, this.description);

  /// 스토어 상품 id.
  final String id;
  final String title;
  final String description;

  static Product? byId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 상품 효과 수치. 첫 값 — 단일 출처.
abstract final class ProductEffects {
  static const double storagePackMultiplier = 1.5;
  static const double outputBoostMultiplier = 1.5;
}
