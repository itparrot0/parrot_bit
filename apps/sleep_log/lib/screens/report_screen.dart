import 'package:flutter/material.dart';

/// 리포트 — 태그별 평균 수면시간 대조.
///
/// 구현 예정: 기록 2주 미만이면 리포트를 보여주지 않는다. 표본이 적을 때 나오는
/// 상관은 틀리고, 틀린 인상을 한 번 주면 신뢰를 잃는다
/// (docs/screen-flow/sleep_log.md §5).
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: const Center(child: Text('수면–감정 대조 — 구현 예정')),
    );
  }
}
