import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// 설정 — 진동·구매 복원·개인정보처리방침 자리 (화면 흐름 §1).
/// 해당 기능이 붙을 때 항목을 채운다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        ListTile(title: Text('진동'), trailing: Text('준비 중')),
        ListTile(title: Text('구매 복원'), trailing: Text('준비 중')),
        ListTile(title: Text('개인정보처리방침'), trailing: Text('준비 중')),
        ListTile(title: Text('버전'), trailing: Text('0.1.0')),
      ],
    ),
  );
}
