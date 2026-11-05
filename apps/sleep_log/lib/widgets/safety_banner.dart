import 'package:flutter/material.dart';

import '../domain/domain.dart';

/// 달력 상단의 조용한 안전 안내 (docs/prd/sleep_log.md §9-2).
///
/// - 차단 모달이 아니라 닫을 수 있는 카드다. 경고색(빨강)을 쓰지 않는다.
/// - **진단하지 않고 사용자를 주체로 둔다.** "우울증일 수 있습니다" ✗ /
///   "혹시 도움이 필요하다면" ✓. 앱이 본 것(기록)만 말하고 판단은 하지 않는다.
class SafetyBannerCard extends StatelessWidget {
  const SafetyBannerCard({
    required this.advice,
    required this.onDismiss,
    super.key,
  });

  /// [SafetyAdvice.none]이면 그리지 않는다 — 부르는 쪽이 거른다.
  final SafetyAdvice advice;

  final VoidCallback onDismiss;

  /// 상담 연락처 (PRD §9-2). 2026-11 확인: 109는 2024년 1월부터 기존 1393을
  /// 대신하는 자살예방 통합 번호, 1577-0199는 지역 정신건강복지센터로 연결되는
  /// 24시간 위기상담. **번호가 바뀐 이력이 있으니 출시 전에 다시 확인한다.**
  static const List<({String name, String number})> contacts = [
    (name: '자살예방상담전화', number: '109'),
    (name: '정신건강위기상담전화', number: '1577-0199'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = switch (advice) {
      SafetyAdvice.restSuggestion => (
        '요즘 조금 지쳐 보여요',
        '최근 며칠, 힘든 기분을 기록한 날이 이어졌고 목표보다 적게 잔 날도 '
            '많았어요. 오늘은 조금 일찍 잠자리에 들어 보는 건 어때요?',
      ),
      SafetyAdvice.supportContact => (
        '혹시 도움이 필요하다면',
        '최근 2주 동안 잠은 충분히 잤는데도 힘든 기분을 기록한 날이 많았어요. '
            '이야기를 나눌 곳이 필요하다면 언제든 연락할 수 있어요. 24시간 열려 있어요.',
      ),
      SafetyAdvice.none => ('', ''),
    };

    return Card(
      key: const Key('safetyBanner'),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.favorite_border,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodyMedium),
                    if (advice == SafetyAdvice.supportContact) ...[
                      const SizedBox(height: 8),
                      for (final contact in contacts)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${contact.name}  '),
                              TextSpan(
                                text: contact.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: '닫기',
            ),
          ],
        ),
      ),
    );
  }
}
