// 인앱 결제: "광고 제거"(비소모성 1개) + 골드 구매(소모성 4개, economy/gold_packs.dart).
//
// 출시 전 할 일: Play Console 에서 상품 `remove_ads`, `gold_500`, `gold_1100`, `gold_3000`, `gold_6500` 을 만든다
// (App Store Connect 도 같은 id). 상품이 없거나 스토어에 연결할 수 없으면 구매는 실패로 끝난다 (게임은 그대로 진행).
//
// 소모성 상품은 결제가 "나중에" 끝날 수도 있다 (편의점·계좌 결제 등 대기 결제, 앱을 끈 사이 완료).
// 그래서 앱이 켜져 있는 동안 결제 결과를 늘 듣고([start]), 완료된 소모성 결제는 [onConsumable] 로 지급한 **뒤에**
// 스토어에 완료를 알린다 — 지급 전에 앱이 꺼지면 다음 실행 때 스토어가 다시 알려 준다. 같은 주문은 한 번만 지급
// (주문 id 를 저장해 확인, save_store.dart).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../economy/gold_packs.dart';

class Products {
  static const removeAds = 'remove_ads';
  static Set<String> get consumables => {for (final p in goldPacks) p.id};
}

enum BuyResult {
  /// 결제 완료 (지급까지 끝남)
  purchased,

  /// 결제 대기 중 (끝나면 저절로 지급)
  pending,

  /// 사용자가 취소
  canceled,

  /// 실패 (스토어 연결 안 됨·상품 없음 등)
  failed,
}

/// 소모성 결제 완료 → 지급. 같은 [orderId] 가 두 번 와도 한 번만 지급해야 한다
typedef ConsumableHandler =
    Future<void> Function(String productId, String orderId);

abstract class Billing {
  /// 앱 시작 때 한 번: 결제 결과를 듣기 시작한다 (지난번에 끝나지 않은 결제도 여기서 받는다)
  Future<void> start();

  /// 소모성 결제가 끝났을 때 부를 지급 함수 (앱이 설정)
  ConsumableHandler? onConsumable;

  /// 비소모성(광고 제거) 구매. 성공하면 true
  Future<bool> purchase(String productId);

  /// 소모성(골드) 구매. 완료되면 [onConsumable] 로 지급한 뒤 purchased
  Future<BuyResult> buyConsumable(String productId);

  /// 상품별 현지 가격 문자열 (스토어에서 못 받으면 빈 맵)
  Future<Map<String, String>> prices(Set<String> productIds);

  /// 기기를 바꾸거나 재설치했을 때 구매 복원 (비소모성만). 복원된 상품 id 목록
  Future<List<String>> restore();
}

/// 개발용(웹·테스트): 결제 없이 바로 지급
class DevBilling extends Billing {
  int _order = 0;

  /// 테스트: 다음 소모성 구매 결과를 바꿔 끼운다
  BuyResult next = BuyResult.purchased;

  @override
  Future<void> start() async {}

  @override
  Future<bool> purchase(String productId) async => true;

  @override
  Future<BuyResult> buyConsumable(String productId) async {
    final r = next;
    if (r == BuyResult.purchased) {
      await onConsumable?.call(productId, 'dev-${_order++}');
    }
    return r;
  }

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => const {};

  @override
  Future<List<String>> restore() async => const [];
}

/// Google Play / App Store 결제 (in_app_purchase)
class StoreBilling extends Billing {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 지금 진행 중인 소모성 구매 (상품 id → 결과 기다림)
  final Map<String, Completer<BuyResult>> _waiting = {};

  @override
  Future<void> start() async {
    _sub ??= _iap.purchaseStream.listen(
      (list) async {
        for (final p in list) {
          if (Products.consumables.contains(p.productID)) {
            await _consumable(p);
          }
        }
      },
      onError: (_) {
        for (final c in _waiting.values) {
          if (!c.isCompleted) c.complete(BuyResult.failed);
        }
        _waiting.clear();
      },
    );
  }

  Future<void> _consumable(PurchaseDetails p) async {
    final waiting = _waiting[p.productID];
    void done(BuyResult r) {
      if (waiting != null && !waiting.isCompleted) waiting.complete(r);
      if (r != BuyResult.pending) _waiting.remove(p.productID);
    }

    switch (p.status) {
      case PurchaseStatus.pending:
        done(BuyResult.pending);
        return; // 끝나면 다시 온다
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        try {
          // 지급 먼저, 그다음 완료 알림 (지급 전에 꺼지면 다음 실행 때 다시 온다)
          await onConsumable?.call(
            p.productID,
            p.purchaseID ?? p.verificationData.serverVerificationData,
          );
          await _finishConsumable(p);
          done(BuyResult.purchased);
        } catch (_) {
          done(BuyResult.failed);
        }
      case PurchaseStatus.canceled:
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        done(BuyResult.canceled);
      case PurchaseStatus.error:
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        done(BuyResult.failed);
    }
  }

  /// 지급한 소모성 결제를 스토어에서 끝낸다 → 같은 상품을 다시 살 수 있다.
  /// Android 는 직접 소모(consume)한다 — 플러그인의 autoConsume 은 지급 전에 소모하고,
  /// 앱을 다시 켠 뒤 도착한 결제는 소모하지 않아 그 상품을 다시 못 사게 된다.
  Future<void> _finishConsumable(PurchaseDetails p) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(p);
    } else if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }

  @override
  Future<BuyResult> buyConsumable(String productId) async {
    try {
      await start();
      if (!await _iap.isAvailable()) return BuyResult.failed;
      final r = await _iap.queryProductDetails({productId});
      if (r.productDetails.isEmpty) return BuyResult.failed;
      final c = _waiting[productId] = Completer<BuyResult>();
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: r.productDetails.first),
        autoConsume: false, // 지급한 뒤 직접 소모 (_finishConsumable)
      );
      if (!started) {
        _waiting.remove(productId);
        return BuyResult.failed;
      }
      // 결제창이 오래 떠 있을 수 있다. 그 사이 끝나지 않으면 대기 결제로 본다 (끝나면 저절로 지급)
      return await c.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => BuyResult.pending,
      );
    } catch (_) {
      _waiting.remove(productId);
      return BuyResult.failed;
    }
  }

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async {
    try {
      if (!await _iap.isAvailable()) return const {};
      final r = await _iap.queryProductDetails(productIds);
      return {for (final d in r.productDetails) d.id: d.price};
    } catch (_) {
      return const {};
    }
  }

  /// 구매·복원 결과를 잠시 모은다 (비소모성용). 스토어는 결과를 purchaseStream 으로만 알려 준다
  Future<List<PurchaseDetails>> _collect(
    Future<void> Function() start,
    bool Function(List<PurchaseDetails>) done,
    Duration timeout,
  ) async {
    final got = <PurchaseDetails>[];
    final finished = Completer<void>();
    final sub = _iap.purchaseStream.listen((list) async {
      // 소모성은 위의 상시 리스너가 지급 후 완료 처리한다 — 여기서 먼저 완료하면 안 된다
      final mine = [
        for (final p in list)
          if (!Products.consumables.contains(p.productID)) p,
      ];
      for (final p in mine) {
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
      got.addAll(mine);
      if (done(mine) && !finished.isCompleted) finished.complete();
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
