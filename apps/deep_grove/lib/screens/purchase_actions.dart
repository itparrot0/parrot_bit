import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../economy/products.dart';
import '../economy/providers.dart';

/// 구매 → 지급 → 안내. 상점에서 쓴다.
Future<void> buyProduct(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(billingProvider).purchase(product.id);
  if (ok) {
    ref.read(economyProvider.notifier).grant([product]);
    ref.read(analyticsProvider).logEvent('purchase_completed', {
      'product': product.id,
    });
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(ok ? '${withObject(product.title)} 받았어요' : '구매하지 않았어요'),
    ),
  );
}

/// 구매 복원 → 지급 → 안내. 상점·설정 공용.
Future<void> restorePurchases(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final ids = await ref.read(billingProvider).restore();
  final products = [for (final id in ids) ?Product.byId(id)];
  final before = ref.read(economyProvider).owned;
  ref.read(economyProvider.notifier).grant(products);
  final fresh = products.where((p) => !before.contains(p)).toList();
  ref.read(analyticsProvider).logEvent('purchase_restored', {
    'count': products.length,
  });
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        products.isEmpty
            ? '복원할 구매가 없어요'
            : fresh.isEmpty
            ? '이미 모두 받은 상품이에요'
            : '복원했어요: ${fresh.map((p) => p.title).join(', ')}',
      ),
    ),
  );
}

/// 받침에 맞춰 목적격 조사를 붙인다 ("창고 확장팩을", "가속을", "상자를").
String withObject(String word) {
  final last = word.isEmpty ? 0 : word.codeUnitAt(word.length - 1);
  final hangul = last >= 0xAC00 && last <= 0xD7A3;
  final hasBatchim = hangul && (last - 0xAC00) % 28 != 0;
  return '$word${hasBatchim || !hangul ? '을' : '를'}';
}
