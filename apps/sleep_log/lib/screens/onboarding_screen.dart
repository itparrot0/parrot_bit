import 'package:flutter/material.dart';

/// 최초 실행 — 목표 수면시간 설정.
///
/// 이 값이 없으면 z 표시가 성립하지 않으므로, 설정 전에는 달력으로 보내지 않는다
/// (docs/screen-flow/sleep_log.md §5).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('목표 수면시간 설정 — 구현 예정')),
    );
  }
}
