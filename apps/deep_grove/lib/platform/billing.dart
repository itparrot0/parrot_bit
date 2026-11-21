// 인앱 결제: 비소모성 상품 2종 (lib/economy/products.dart).
//
// 출시 전 할 일: Play Console·App Store Connect 에 `storage_pack`, `output_boost` 를
// 비소모성(관리형) 상품으로 만든다. 상품이 없거나 스토어에 연결할 수 없으면 purchase 는 false,
// restore 는 빈 목록, prices 는 빈 맵을 돌려준다 (게임은 그대로 진행).
// 구조는 Bloom Wave 의 StoreBilling 과 같다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract interface class Billing {
  /// 스토어가 알려 준 표시 가격 (상품 id → "₩3,300" 같은 문자열). 모르면 빠진다.
  Future<Map<String, String>> prices(Set<String> productIds);

  /// 구매. 결제가 끝나 상품을 받았으면 true. 취소·실패는 false. 던지지 않는다.
  Future<bool> purchase(String productId);

  /// 기기를 바꾸거나 재설치했을 때 구매 복원. 복원된 상품 id 목록.
  Future<List<String>> restore();
}

/// 이 기기에서 쓸 결제. 스토어 결제는 Android·iOS 에서만 돈다.
Billing platformBilling(GlobalKey<NavigatorState> navigatorKey) =>
    !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
    ? StoreBilling()
    : MockBilling(navigatorKey);

/// Google Play / App Store 결제 (in_app_purchase).
class StoreBilling implements Billing {
  final InAppPurchase _iap = InAppPurchase.instance;

  /// 구매·복원 결과를 기다린다. 스토어는 결과를 purchaseStream 으로만 알려 준다.
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
  Future<Map<String, String>> prices(Set<String> productIds) async {
    try {
      if (!await _iap.isAvailable()) return const {};
      final r = await _iap.queryProductDetails(productIds);
      return {for (final d in r.productDetails) d.id: d.price};
    } catch (_) {
      return const {};
    }
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

/// 개발용(웹·데스크톱) 가짜 결제: 구매할지 취소할지 고르는 창을 띄운다.
/// 복원은 이 기기에서 산 적이 있는 것만 돌려준다 (앱을 새로 열면 비어 있다).
class MockBilling implements Billing {
  MockBilling(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  final Set<String> _bought = {};

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => {
    for (final id in productIds) id: '테스트',
  };

  @override
  Future<bool> purchase(String productId) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('결제 (테스트)'),
        content: Text('실제 기기에서는 여기서 스토어 결제 창이 떠요.\n상품: $productId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('구매'),
          ),
        ],
      ),
    );
    if (ok ?? false) _bought.add(productId);
    return ok ?? false;
  }

  @override
  Future<List<String>> restore() async => _bought.toList();
}
