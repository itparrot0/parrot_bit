import 'package:flutter/material.dart';

/// 홈 — 월간 달력. 날짜 칸에 z 단계를 표시한다 (PRD §4).
///
/// 구현 예정: 오늘 기록이 없으면 상단에 "오늘 기록" CTA,
/// 기록 없는 날은 빈칸으로 수면 부족과 구분, 안전 배너(PRD §9-2) 노출 위치.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('슬립로그')),
      body: const Center(child: Text('달력 — 구현 예정')),
    );
  }
}
