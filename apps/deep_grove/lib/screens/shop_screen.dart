import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../economy/products.dart';
import '../economy/providers.dart';
import 'purchase_actions.dart';

/// 상점 — 비소모성 IAP 2종 + 구매 복원 (PRD §6, 화면 흐름 §5 `shop`).
/// 결제 실패·취소는 화면을 떠나지 않고 짧은 안내만 한다.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  Map<String, String> _prices = const {};

  /// 결제 창이 떠 있는 동안 버튼을 막는다 (두 번 누름 방지).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(billingProvider)
        .prices({for (final p in Product.values) p.id})
        .then((prices) {
          if (mounted) setState(() => _prices = prices);
        });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(loadedGroveProvider) is! AsyncData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final economy = ref.watch(economyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('상점')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final product in Product.values)
            ListTile(
              key: ValueKey('product-${product.id}'),
              leading: Icon(switch (product) {
                Product.storagePack => Icons.inventory_2_outlined,
                Product.outputBoost => Icons.speed,
              }),
              title: Text(product.title),
              subtitle: Text(product.description),
              trailing: economy.owns(product)
                  ? const Chip(label: Text('구매함'))
                  : FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => buyProduct(context, ref, product)),
                      child: Text(_prices[product.id] ?? '구매'),
                    ),
            ),
          const Divider(),
          ListTile(
            title: const Text('구매 복원'),
            subtitle: const Text('기기를 바꿨거나 다시 설치했을 때'),
            trailing: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => restorePurchases(context, ref)),
              child: const Text('복원'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('보드 확장은 상품으로 살 수 없어요. 자원으로만 열려요.'),
          ),
        ],
      ),
    );
  }
}
