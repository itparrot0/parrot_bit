import 'package:flutter/material.dart';

/// 일별 기록 — 취침·기상 시각과 감정 태그.
///
/// 구현 예정: 자정 넘김을 묻지 않고 "취침은 전날, 기상은 당일"로 해석,
/// 입력 즉시 수면시간과 z 단계를 같이 보여주기, 태그 0개로도 저장 허용
/// (docs/screen-flow/sleep_log.md §5).
class EntryScreen extends StatelessWidget {
  const EntryScreen({required this.date, super.key});

  /// 기록 대상 날짜 (ISO-8601 yyyy-MM-dd).
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(date)),
      body: const Center(child: Text('일별 기록 — 구현 예정')),
    );
  }
}
