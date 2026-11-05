import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// 상점 — 비소모성 IAP 2종 자리 (PRD §6). 결제 연결 전이라 목록만 보여 준다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('상점')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        ListTile(
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('창고 확장팩'),
          subtitle: Text('자원별 창고 용량 영구 증가'),
          trailing: Text('준비 중'),
        ),
        ListTile(
          leading: Icon(Icons.speed),
          title: Text('영구 산출 가속'),
          subtitle: Text('산출원 산출량 영구 증가'),
          trailing: Text('준비 중'),
        ),
        Divider(),
        ListTile(title: Text('구매 복원'), trailing: Text('준비 중')),
      ],
    ),
  );
}
