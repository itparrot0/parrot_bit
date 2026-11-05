/// 태그 묶음. 시각적 분류가 아니라 **기능적 분류**다 — 안전 안내 판정이
/// [negative] 여부를 읽는다 (docs/prd/sleep_log.md §9-2).
///
/// 그래서 커스텀 태그(v1.x)도 묶음을 반드시 정해야 한다. 묶음 없는 태그는
/// 안전 판정에서 보이지 않게 된다.
enum MoodGroup {
  /// 감정적 부정 — 안전 안내 판정의 대상.
  negative,

  /// 감정적 긍정.
  positive,

  /// 신체·에너지. 수면 부족은 감정보다 몸으로 먼저 나타나므로 따로 둔다.
  ///
  /// **안전 판정에 넣지 않는다.** "피곤"은 바빴다는 뜻일 수도 있어서,
  /// 이걸 부정으로 세면 상담 안내가 엉뚱하게 뜬다.
  physical,

  /// 생활 — 어제 한 일(커피, 운동, 자기 전 휴대폰…). 감정이 아니라 **행동**이라
  /// 안전 판정에 넣지 않고, 입력 화면에서도 "어제 하루"로 따로 묻는다.
  /// 리포트에서 "커피 마신 날 평균 수면"처럼 스스로 바꿀 수 있는 것과의 대조가
  /// 된다 (PRD §3-5).
  lifestyle;

  /// 기분·몸 묶음인가 (입력 화면의 "지금 상태").
  bool get isMood => this != lifestyle;
}

/// 감정 태그 하나.
final class MoodTag {
  const MoodTag({required this.id, required this.label, required this.group});

  /// 저장 키. [label]과 분리한 이유는 표시 문구를 고쳐도 기존 기록이
  /// 고아가 되지 않게 하기 위함이다.
  final String id;

  final String label;
  final MoodGroup group;

  @override
  bool operator ==(Object other) => other is MoodTag && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MoodTag($id)';
}

/// v1 기본 팔레트 15개 (PRD §3-1).
///
/// 이 목록을 12~16개로 유지한다 — 길어지면 매일 훑는 비용이 누적돼 기록을
/// 포기하게 된다. 커스텀 태그는 v1.x에서 이 위에 더해진다 (PRD §3-2).
abstract final class DefaultMoodTags {
  static const anxious = MoodTag(
    id: 'anxious',
    label: '불안',
    group: MoodGroup.negative,
  );
  static const down = MoodTag(
    id: 'down',
    label: '우울',
    group: MoodGroup.negative,
  );
  static const irritated = MoodTag(
    id: 'irritated',
    label: '짜증',
    group: MoodGroup.negative,
  );
  static const listless = MoodTag(
    id: 'listless',
    label: '무기력',
    group: MoodGroup.negative,
  );
  static const lonely = MoodTag(
    id: 'lonely',
    label: '외로움',
    group: MoodGroup.negative,
  );

  static const calm = MoodTag(
    id: 'calm',
    label: '평온',
    group: MoodGroup.positive,
  );
  static const joyful = MoodTag(
    id: 'joyful',
    label: '기쁨',
    group: MoodGroup.positive,
  );
  static const excited = MoodTag(
    id: 'excited',
    label: '설렘',
    group: MoodGroup.positive,
  );
  static const proud = MoodTag(
    id: 'proud',
    label: '뿌듯함',
    group: MoodGroup.positive,
  );
  static const grateful = MoodTag(
    id: 'grateful',
    label: '감사',
    group: MoodGroup.positive,
  );

  static const tired = MoodTag(
    id: 'tired',
    label: '피곤',
    group: MoodGroup.physical,
  );
  static const sleepy = MoodTag(
    id: 'sleepy',
    label: '졸림',
    group: MoodGroup.physical,
  );
  static const refreshed = MoodTag(
    id: 'refreshed',
    label: '상쾌함',
    group: MoodGroup.physical,
  );
  static const heavy = MoodTag(
    id: 'heavy',
    label: '몸이 무거움',
    group: MoodGroup.physical,
  );
  static const headache = MoodTag(
    id: 'headache',
    label: '두통',
    group: MoodGroup.physical,
  );

  static const List<MoodTag> all = [
    anxious,
    down,
    irritated,
    listless,
    lonely,
    calm,
    joyful,
    excited,
    proud,
    grateful,
    tired,
    sleepy,
    refreshed,
    heavy,
    headache,
  ];

  // 생활 태그 (PRD §3-1 생활). 기분 팔레트(12~16개 제한)와 따로 센다.
  static const caffeine = MoodTag(
    id: 'caffeine',
    label: '커피·카페인',
    group: MoodGroup.lifestyle,
  );
  static const alcohol = MoodTag(
    id: 'alcohol',
    label: '술',
    group: MoodGroup.lifestyle,
  );
  static const exercise = MoodTag(
    id: 'exercise',
    label: '운동',
    group: MoodGroup.lifestyle,
  );
  static const nap = MoodTag(
    id: 'nap',
    label: '낮잠',
    group: MoodGroup.lifestyle,
  );
  static const screenAtBed = MoodTag(
    id: 'screen_at_bed',
    label: '자기 전 휴대폰',
    group: MoodGroup.lifestyle,
  );
  static const lateMeal = MoodTag(
    id: 'late_meal',
    label: '늦은 야식',
    group: MoodGroup.lifestyle,
  );
  static const lateWork = MoodTag(
    id: 'late_work',
    label: '늦게까지 일·공부',
    group: MoodGroup.lifestyle,
  );

  /// 생활 태그 7개. 기분 팔레트 [all]과 따로 둔다.
  static const List<MoodTag> lifestyle = [
    caffeine,
    alcohol,
    exercise,
    nap,
    screenAtBed,
    lateMeal,
    lateWork,
  ];

  /// 기분·몸 + 생활 전부. 저장된 id를 되찾을 때 쓴다.
  static const List<MoodTag> everything = [...all, ...lifestyle];

  static List<MoodTag> ofGroup(MoodGroup group) =>
      everything.where((tag) => tag.group == group).toList();

  static MoodTag? byId(String id) {
    for (final tag in everything) {
      if (tag.id == id) {
        return tag;
      }
    }
    return null;
  }
}
