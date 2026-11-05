// 인앱 결제: 지금은 "광고 제거" 관리형 상품 하나. 상점·아이템이 생기면 여기에 상품을 늘린다.
//
// 출시 전 할 일: Play Console 에서 관리형 상품 `remove_ads` 를 만든다. 상품이 없거나 스토어에
// 연결할 수 없으면 purchase 는 false, restore 는 빈 목록을 돌려준다 (게임은 그대로 진행).
import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class Products {
  static const removeAds = 'remove_ads';
}

abstract class Billing {
  Future<bool> purchase(String productId);

  /// 기기를 바꾸거나 재설치했을 때 구매 복원. 복원된 상품 id 목록
  Future<List<String>> restore();
}

/// 개발용(웹·테스트): 결제 없이 바로 지급
class DevBilling implements Billing {
  @override
  Future<bool> purchase(String productId) async => true;
  @override
  Future<List<String>> restore() async => const [];
}

/// Google Play / App Store 결제 (in_app_purchase)
class StoreBilling implements Billing {
  final InAppPurchase _iap = InAppPurchase.instance;

  /// 구매·복원 결과 한 건을 기다린다. 스토어는 결과를 purchaseStream 으로만 알려 준다
  Future<List<PurchaseDetails>> _collect(
    Future<void> Function() start,
    bool Function(List<PurchaseDetails>) done,
    Duration timeout,
  ) async {
    final got = <PurchaseDetails>[];
    final finished = Completer<void>();
    final sub = _iap.purchaseStream.listen((list) async {
      for (final p in list) {
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
      got.addAll(list);
      if (done(list) && !finished.isCompleted) finished.complete();
    }, onError: (_) => finished.isCompleted ? null : finished.complete());
    try {
      await start();
      await finished.future.timeout(timeout, onTimeout: () {});
    } finally {
      await sub.cancel();
    }
    return got;
  }

  @override
  Future<bool> purchase(String productId) async {
    try {
      if (!await _iap.isAvailable()) return false;
      final r = await _iap.queryProductDetails({productId});
      if (r.productDetails.isEmpty) return false;
      final got = await _collect(
        () => _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: r.productDetails.first),
        ),
        (list) => list.any(
          (p) => p.productID == productId && p.status != PurchaseStatus.pending,
        ),
        const Duration(minutes: 5),
      );
      return got.any(
        (p) =>
            p.productID == productId &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> restore() async {
    try {
      if (!await _iap.isAvailable()) return const [];
      final got = await _collect(
        _iap.restorePurchases,
        (_) => false, // 복원은 끝 신호가 없어 잠시 모아 본다
        const Duration(seconds: 6),
      );
      return {
        for (final p in got)
          if (p.status == PurchaseStatus.restored ||
              p.status == PurchaseStatus.purchased)
            p.productID,
      }.toList();
    } catch (_) {
      return const [];
    }
  }
}
