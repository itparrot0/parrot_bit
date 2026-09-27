import 'package:flutter/material.dart';

/// 설정 — 목표 수면시간, 리마인더, 안전 안내 on/off, 데이터 삭제·내보내기.
///
/// 구현 예정: 목표 수면시간을 바꾸면 과거 z 표시가 전부 재계산된다는 것을 미리
/// 알린다. 저장된 것은 수면시간이고 z는 목표 대비 판정이므로, 안내 없이 지난
/// 달력이 달라지면 버그로 보인다 (docs/screen-flow/sleep_log.md §5).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: const Center(child: Text('설정 — 구현 예정')),
    );
  }
}
