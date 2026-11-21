import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../economy/providers.dart';
import 'purchase_actions.dart';

/// 설정 (화면 흐름 §1). 진동·개인정보처리방침은 해당 기능이 붙을 때 채운다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(loadedGroveProvider) is AsyncData;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const ListTile(title: Text('진동'), trailing: Text('준비 중')),
          ListTile(
            title: const Text('구매 복원'),
            trailing: OutlinedButton(
              onPressed: loaded ? () => restorePurchases(context, ref) : null,
              child: const Text('복원'),
            ),
          ),
          const ListTile(title: Text('개인정보처리방침'), trailing: Text('준비 중')),
          const ListTile(title: Text('버전'), trailing: Text('0.1.0')),
        ],
      ),
    );
  }
}
