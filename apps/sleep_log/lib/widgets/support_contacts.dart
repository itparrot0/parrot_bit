import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// 상담 연락처 (PRD §9-2). 2026-11 확인: 109는 2024년 1월부터 기존 1393을
/// 대신하는 자살예방 통합 번호, 1577-0199는 지역 정신건강복지센터로 연결되는
/// 24시간 위기상담. **번호가 바뀐 이력이 있으니 출시 전에 다시 확인한다.**
abstract final class SupportContacts {
  static const List<({String name, String number})> all = [
    (name: '자살예방상담전화', number: '109'),
    (name: '정신건강위기상담전화', number: '1577-0199'),
  ];
}

/// 누르면 전화 앱이 그 번호로 열리는 연락처 목록. 배너와 설정이 같이 쓴다.
class SupportContactButtons extends ConsumerWidget {
  const SupportContactButtons({this.foreground, super.key});

  /// 글자·아이콘 색. 배너처럼 배경색이 있는 곳에서 맞춘다.
  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = foreground ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final contact in SupportContacts.all)
          TextButton.icon(
            key: Key('call.${contact.number}'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _call(context, ref, contact.number),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${contact.name}  '),
                  TextSpan(
                    text: contact.number,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String number) async {
    final opened = await ref.read(phoneDialerProvider).dial(number);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전화를 열 수 없는 기기예요. 다른 전화로 $number에 걸어 주세요.')),
      );
    }
  }
}
