// 라이프 = 햇빛 (2026-11-05). 조절 지점은 이 파일 한 곳.
//
// - 최대 [maxLives]개. 모자라면 [lifeRegen]마다 1개씩 저절로 찬다 (앱이 꺼져 있어도 시각으로 계산).
// - 스테이지를 시작할 때 1개를 쓰고, 완성하면 돌려받는다 → 실패하거나 도중에 그만두면(다시 하기·홈·앱 종료) 1개가 줄어든다.
// - 0개면 시작할 수 없다. 한 번에 가득 채우는 방법 두 가지:
//     골드 [refillGoldCost] 로 채우기 (언제든)
//     보상형 광고 보고 채우기 (하루 1번, 아침 [adResetHour]시에 다시 가능)
// - 기기 시계를 뒤로 돌리면 회복 기준 시각을 지금으로 당긴다 (회복이 멈추지 않게, 미래 시각으로 몰아 받지 못하게).

const maxLives = 5;
const lifeRegen = Duration(minutes: 20);
const refillGoldCost = 100;

/// 광고 충전 하루 경계 (현지 시각)
const adResetHour = 6;

class Lives {
  Lives({this.count = maxLives, this.anchorMs, this.adDay = ''});

  /// 지금 개수 ([settle] 뒤에 정확하다)
  int count;

  /// 회복을 세기 시작한 시각 (epoch ms). 가득 차 있으면 null
  int? anchorMs;

  /// 광고로 채운 날 ([adDayKey] 형식). 오늘 키와 같으면 오늘은 이미 썼다
  String adDay;

  /// 지금 시각까지 저절로 찬 만큼 반영한다
  void settle(DateTime now) {
    final t = now.millisecondsSinceEpoch;
    if (count >= maxLives) {
      count = maxLives;
      anchorMs = null;
      return;
    }
    var a = anchorMs ?? t;
    if (a > t) a = t; // 시계를 뒤로 돌림
    final step = lifeRegen.inMilliseconds;
    final gained = (t - a) ~/ step;
    count += gained;
    if (count >= maxLives) {
      count = maxLives;
      anchorMs = null;
    } else {
      anchorMs = a + gained * step;
    }
  }

  /// 1개 쓰기. 없으면 false
  bool spend(DateTime now) {
    settle(now);
    if (count <= 0) return false;
    if (count == maxLives) anchorMs = now.millisecondsSinceEpoch;
    count--;
    return true;
  }

  /// 1개 돌려받기 (완성). 최대를 넘지 않는다
  void refund(DateTime now) {
    settle(now);
    count++;
    settle(now);
  }

  void fill() {
    count = maxLives;
    anchorMs = null;
  }

  bool get full => count >= maxLives;

  /// 다음 1개가 찰 때까지 남은 시간 (가득이면 null)
  Duration? untilNext(DateTime now) {
    settle(now);
    if (full) return null;
    final left =
        anchorMs! + lifeRegen.inMilliseconds - now.millisecondsSinceEpoch;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  bool adAvailable(DateTime now) => adDay != adDayKey(now);

  Map<String, dynamic> toJson() => {
    'count': count,
    'anchor': anchorMs,
    'adDay': adDay,
  };

  static Lives fromJson(Object? raw) {
    final l = Lives();
    if (raw is! Map) return l;
    final c = raw['count'];
    if (c is num) l.count = c.floor().clamp(0, maxLives);
    final a = raw['anchor'];
    if (a is num && l.count < maxLives) l.anchorMs = a.floor();
    if (l.count < maxLives && l.anchorMs == null) {
      l.anchorMs = DateTime.now().millisecondsSinceEpoch;
    }
    final d = raw['adDay'];
    if (d is String) l.adDay = d;
    return l;
  }
}

/// 광고 충전용 "하루" 이름: 아침 [adResetHour]시 전은 전날로 친다
String adDayKey(DateTime now) {
  final d = now.subtract(const Duration(hours: adResetHour));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// "mm:ss" (1시간 이상이면 "h:mm:ss")
String formatLeft(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  String two(int v) => v.toString().padLeft(2, '0');
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}
