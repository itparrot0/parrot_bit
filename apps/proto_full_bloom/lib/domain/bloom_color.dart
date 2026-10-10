/// 칸과 물뿌리개의 색.
///
/// 프로토타입이라 고정 목록으로 둔다. 색 수는 난이도 다이얼이므로
/// (PRD §4.4) 레벨이 이 중 몇 개를 쓸지 고른다.
enum BloomColor {
  red('빨강'),
  blue('파랑'),
  yellow('노랑'),
  green('초록'),
  purple('보라');

  const BloomColor(this.label);

  final String label;
}
