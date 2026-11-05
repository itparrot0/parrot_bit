// 세계 국기 (2026-11-05, 3000 스테이지 확장용). 이름은 f_<대륙>_<나라 코드>, 같은 대륙이 한 유형(familyOf)이다.
// 30×20 (600칸), 배율 1. 도형으로 정확히 그릴 수 있는 국기만 골랐다 (문장·글자가 들어간 복잡한 국기는 뺐다).
// 비율·세부는 칸 크기에 맞춰 단순화했다. 색은 6개 이하.
import 'dart:math' as math;

import 'art_gen.dart';
import 'art_source.dart';

const _w = 30, _h = 20;

Grid _flag() => Grid(_w, _h);

/// 가로 줄무늬 (위에서부터, 비율 weights)
void _hs(Grid g, List<String> cs, [List<double>? ws]) {
  final w = ws ?? List.filled(cs.length, 1.0);
  final total = w.reduce((a, b) => a + b);
  g.each((x, y) => true, cs.first);
  var acc = 0.0;
  for (var i = 0; i < cs.length; i++) {
    final top = acc / total * _h, bottom = (acc + w[i]) / total * _h;
    g.each((x, y) => y >= top && y < bottom, cs[i]);
    acc += w[i];
  }
}

/// 세로 줄무늬 (왼쪽부터)
void _vs(Grid g, List<String> cs, [List<double>? ws]) {
  final w = ws ?? List.filled(cs.length, 1.0);
  final total = w.reduce((a, b) => a + b);
  var acc = 0.0;
  for (var i = 0; i < cs.length; i++) {
    final l = acc / total * _w, r = (acc + w[i]) / total * _w;
    g.each((x, y) => x >= l && x < r, cs[i]);
    acc += w[i];
  }
}

/// 오각별
void _star(
  Grid g,
  double cx,
  double cy,
  double r,
  String ch, [
  double rot = -math.pi / 2,
]) {
  final pts = <(double, double)>[];
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? r : r * 0.42;
    final a = rot + k * math.pi / 5;
    pts.add((cx + math.cos(a) * rr, cy + math.sin(a) * rr));
  }
  g.poly(pts, ch);
}

/// 초승달: ch 원에서 bg 원을 오른쪽으로 비켜 지운다
void _crescent(
  Grid g,
  double cx,
  double cy,
  double r,
  String ch,
  String bg, [
  double off = 0.28,
]) {
  g.ell(cx, cy, r, r, ch);
  g.ell(cx + r * off * 1.2, cy, r * 0.82, r * 0.82, bg);
}

/// 노르딕 십자 (세로 막대 중심 x = cx, 가로 막대 중심 y = 10)
void _nordic(Grid g, String bg, String cross, {String? inner, double cx = 11}) {
  g.each((x, y) => true, bg);
  g.each((x, y) => (x - cx).abs() < 2.6 || (y - 10).abs() < 2.6, cross);
  if (inner != null) {
    g.each((x, y) => (x - cx).abs() < 1.3 || (y - 10).abs() < 1.3, inner);
  }
}

/// 유니언 잭 (x0..x1, y0..y1 영역)
void _ujack(Grid g, double x0, double y0, double x1, double y1) {
  final w = x1 - x0, h = y1 - y0;
  bool inR(double x, double y) => x >= x0 && x < x1 && y >= y0 && y < y1;
  double d1(double x, double y) =>
      ((x - x0) / w - (y - y0) / h).abs() * math.min(w, h);
  double d2(double x, double y) =>
      ((x - x0) / w + (y - y0) / h - 1).abs() * math.min(w, h);
  g.each(inR, 'b');
  g.each(
    (x, y) => inR(x, y) && (d1(x, y) < h * 0.13 || d2(x, y) < h * 0.13),
    'w',
  );
  g.each(
    (x, y) => inR(x, y) && (d1(x, y) < h * 0.05 || d2(x, y) < h * 0.05),
    'r',
  );
  g.each(
    (x, y) =>
        inR(x, y) &&
        ((x - (x0 + w / 2)).abs() < h * 0.17 ||
            (y - (y0 + h / 2)).abs() < h * 0.17),
    'w',
  );
  g.each(
    (x, y) =>
        inR(x, y) &&
        ((x - (x0 + w / 2)).abs() < h * 0.09 ||
            (y - (y0 + h / 2)).abs() < h * 0.09),
    'r',
  );
}

typedef _F = (
  String code,
  String region,
  String ko,
  String en,
  Map<String, String> pal,
  void Function(Grid g) draw,
);

const _red = '#D52B1E', _white = '#FFFFFF', _blue = '#0039A6';
const _yellow = '#FCD116', _black = '#000000';

List<_F> _flags() => [
  // ── 유럽 ──
  (
    'fr',
    'eu',
    '프랑스',
    'France',
    {'b': '#0055A4', 'w': _white, 'r': '#EF4135'},
    (g) => _vs(g, ['b', 'w', 'r']),
  ),
  (
    'it',
    'eu',
    '이탈리아',
    'Italy',
    {'g': '#009246', 'w': _white, 'r': '#CE2B37'},
    (g) => _vs(g, ['g', 'w', 'r']),
  ),
  (
    'ie',
    'eu',
    '아일랜드',
    'Ireland',
    {'g': '#169B62', 'w': _white, 'o': '#FF883E'},
    (g) => _vs(g, ['g', 'w', 'o']),
  ),
  (
    'be',
    'eu',
    '벨기에',
    'Belgium',
    {'k': _black, 'y': '#FDDA24', 'r': '#EF3340'},
    (g) => _vs(g, ['k', 'y', 'r']),
  ),
  (
    'ro',
    'eu',
    '루마니아',
    'Romania',
    {'b': '#002B7F', 'y': _yellow, 'r': '#CE1126'},
    (g) => _vs(g, ['b', 'y', 'r']),
  ),
  (
    'de',
    'eu',
    '독일',
    'Germany',
    {'k': _black, 'r': '#DD0000', 'y': '#FFCE00'},
    (g) => _hs(g, ['k', 'r', 'y']),
  ),
  (
    'nl',
    'eu',
    '네덜란드',
    'Netherlands',
    {'r': '#AE1C28', 'w': _white, 'b': '#21468B'},
    (g) => _hs(g, ['r', 'w', 'b']),
  ),
  (
    'ru',
    'eu',
    '러시아',
    'Russia',
    {'w': _white, 'b': _blue, 'r': _red},
    (g) => _hs(g, ['w', 'b', 'r']),
  ),
  (
    'at',
    'eu',
    '오스트리아',
    'Austria',
    {'r': '#ED2939', 'w': _white},
    (g) => _hs(g, ['r', 'w', 'r']),
  ),
  (
    'hu',
    'eu',
    '헝가리',
    'Hungary',
    {'r': '#CE2939', 'w': _white, 'g': '#477050'},
    (g) => _hs(g, ['r', 'w', 'g']),
  ),
  (
    'bg',
    'eu',
    '불가리아',
    'Bulgaria',
    {'w': _white, 'g': '#00966E', 'r': '#D62612'},
    (g) => _hs(g, ['w', 'g', 'r']),
  ),
  (
    'lt',
    'eu',
    '리투아니아',
    'Lithuania',
    {'y': '#FDB913', 'g': '#006A44', 'r': '#C1272D'},
    (g) => _hs(g, ['y', 'g', 'r']),
  ),
  (
    'ee',
    'eu',
    '에스토니아',
    'Estonia',
    {'b': '#0072CE', 'k': _black, 'w': _white},
    (g) => _hs(g, ['b', 'k', 'w']),
  ),
  (
    'lu',
    'eu',
    '룩셈부르크',
    'Luxembourg',
    {'r': '#ED2939', 'w': _white, 'b': '#00A1DE'},
    (g) => _hs(g, ['r', 'w', 'b']),
  ),
  (
    'am',
    'eu',
    '아르메니아',
    'Armenia',
    {'r': '#D90012', 'b': '#0033A0', 'o': '#F2A800'},
    (g) => _hs(g, ['r', 'b', 'o']),
  ),
  (
    'pl',
    'eu',
    '폴란드',
    'Poland',
    {'w': _white, 'r': '#DC143C'},
    (g) => _hs(g, ['w', 'r']),
  ),
  (
    'ua',
    'eu',
    '우크라이나',
    'Ukraine',
    {'b': '#0057B7', 'y': '#FFD700'},
    (g) => _hs(g, ['b', 'y']),
  ),
  (
    'mc',
    'eu',
    '모나코',
    'Monaco',
    {'r': '#CE1126', 'w': _white},
    (g) => _hs(g, ['r', 'w']),
  ),
  (
    'lv',
    'eu',
    '라트비아',
    'Latvia',
    {'r': '#9E3039', 'w': _white},
    (g) => _hs(g, ['r', 'w', 'r'], [2, 1, 2]),
  ),
  (
    'dk',
    'eu',
    '덴마크',
    'Denmark',
    {'r': '#C8102E', 'w': _white},
    (g) => _nordic(g, 'r', 'w', cx: 11),
  ),
  (
    'se',
    'eu',
    '스웨덴',
    'Sweden',
    {'b': '#006AA7', 'y': '#FECC02'},
    (g) => _nordic(g, 'b', 'y'),
  ),
  (
    'no',
    'eu',
    '노르웨이',
    'Norway',
    {'r': '#BA0C2F', 'w': _white, 'b': '#00205B'},
    (g) => _nordic(g, 'r', 'w', inner: 'b'),
  ),
  (
    'fi',
    'eu',
    '핀란드',
    'Finland',
    {'w': _white, 'b': '#002F6C'},
    (g) => _nordic(g, 'w', 'b'),
  ),
  (
    'is',
    'eu',
    '아이슬란드',
    'Iceland',
    {'b': '#02529C', 'w': _white, 'r': '#DC1E35'},
    (g) => _nordic(g, 'b', 'w', inner: 'r'),
  ),
  (
    'ch',
    'eu',
    '스위스',
    'Switzerland',
    {'r': '#DA291C', 'w': _white},
    (g) {
      g.each((x, y) => true, 'r');
      g.each(
        (x, y) =>
            ((x - 15).abs() < 1.6 && (y - 10).abs() < 6) ||
            ((y - 10).abs() < 1.6 && (x - 15).abs() < 6),
        'w',
      );
    },
  ),
  (
    'gr',
    'eu',
    '그리스',
    'Greece',
    {'b': '#0D5EAF', 'w': _white},
    (g) {
      _hs(g, ['b', 'w', 'b', 'w', 'b', 'w', 'b', 'w', 'b']);
      g.each((x, y) => x < 11 && y < 11, 'b');
      g.each(
        (x, y) =>
            x < 11 &&
            y < 11 &&
            ((x - 5.5).abs() < 1.1 || (y - 5.5).abs() < 1.1),
        'w',
      );
    },
  ),
  (
    'cz',
    'eu',
    '체코',
    'Czechia',
    {'w': _white, 'r': '#D7141A', 'b': '#11457E'},
    (g) {
      _hs(g, ['w', 'r']);
      g.poly([(0, 0), (15, 10), (0, 20)], 'b');
    },
  ),
  (
    'gb',
    'eu',
    '영국',
    'United Kingdom',
    {'b': '#012169', 'w': _white, 'r': '#C8102E'},
    (g) => _ujack(g, 0, 0, 30, 20),
  ),
  // ── 아시아 · 중동 ──
  (
    'jp',
    'as',
    '일본',
    'Japan',
    {'w': _white, 'r': '#BC002D'},
    (g) {
      g.each((x, y) => true, 'w');
      g.ell(15, 10, 6, 6, 'r');
    },
  ),
  (
    'kr',
    'as',
    '대한민국',
    'South Korea',
    {'w': _white, 'r': '#CD2E3A', 'b': '#0047A0', 'k': _black},
    (g) {
      g.each((x, y) => true, 'w');
      // 태극: 대각선(왼쪽 위 → 오른쪽 아래) 축 위쪽이 빨강, 아래쪽이 파랑. 축 양 끝에서 서로 둥글게 파고든다
      const r0 = 5.2, ang = 0.588; // atan(20/30)
      bool red(double x, double y) {
        final dx = x - 15, dy = y - 10;
        final u = dx * math.cos(ang) + dy * math.sin(ang);
        final v = -dx * math.sin(ang) + dy * math.cos(ang);
        final inLeft = math.pow(u + r0 / 2, 2) + v * v < r0 * r0 / 4;
        final inRight = math.pow(u - r0 / 2, 2) + v * v < r0 * r0 / 4;
        return inLeft || (v < 0 && !inRight);
      }

      g.each(
        (x, y) => math.pow(x - 15, 2) + math.pow(y - 10, 2) <= r0 * r0,
        'b',
      );
      g.each(
        (x, y) =>
            math.pow(x - 15, 2) + math.pow(y - 10, 2) <= r0 * r0 && red(x, y),
        'r',
      );
      // 4괘: 건(왼쪽 위, 모두 이어짐) 곤(오른쪽 아래, 모두 끊김) 감(오른쪽 위) 리(왼쪽 아래). 막대는 대각선에 수직
      void bars(double cx, double cy, List<bool> solid) {
        final nx = (cx - 15).sign, ny = (cy - 10).sign;
        final len = math.sqrt(nx * nx + ny * ny);
        final ux = nx / len, uy = ny / len; // 중심에서 바깥 방향
        final px = -uy, py = ux; // 막대 방향
        for (var i = 0; i < 3; i++) {
          final ox = cx + ux * (i - 1) * 1.2, oy = cy + uy * (i - 1) * 1.2;
          for (var t = -1.0; t <= 1.0; t += 0.2) {
            if (!solid[i] && t.abs() < 0.3) continue;
            g.ell(ox + px * t * 2.4, oy + py * t * 2.4, 0.55, 0.55, 'k');
          }
        }
      }

      bars(6.5, 4.2, [true, true, true]);
      bars(23.5, 15.8, [false, false, false]);
      bars(23.5, 4.2, [false, true, false]);
      bars(6.5, 15.8, [true, false, true]);
    },
  ),
  (
    'cn',
    'as',
    '중국',
    'China',
    {'r': '#EE1C25', 'y': '#FFFF00'},
    (g) {
      g.each((x, y) => true, 'r');
      _star(g, 5.5, 5.5, 3.6, 'y');
      for (final (sx, sy) in [
        (10.5, 2.2),
        (12.5, 4.5),
        (12.5, 7.5),
        (10.5, 9.6),
      ]) {
        _star(g, sx, sy, 1.3, 'y');
      }
    },
  ),
  (
    'vn',
    'as',
    '베트남',
    'Vietnam',
    {'r': '#DA251D', 'y': '#FFFF00'},
    (g) {
      g.each((x, y) => true, 'r');
      _star(g, 15, 10.6, 6.8, 'y');
    },
  ),
  (
    'in',
    'as',
    '인도',
    'India',
    {'o': '#FF9933', 'w': _white, 'g': '#138808', 'b': '#000080'},
    (g) {
      _hs(g, ['o', 'w', 'g']);
      g.each(
        (x, y) =>
            ((math.sqrt(math.pow(x - 15, 2) + math.pow(y - 10, 2))) - 2.7)
                .abs() <
            0.55,
        'b',
      );
      g.ell(15, 10, 0.7, 0.7, 'b');
    },
  ),
  (
    'bd',
    'as',
    '방글라데시',
    'Bangladesh',
    {'g': '#006A4E', 'r': '#F42A41'},
    (g) {
      g.each((x, y) => true, 'g');
      g.ell(13.5, 10, 6, 6, 'r');
    },
  ),
  (
    'th',
    'as',
    '태국',
    'Thailand',
    {'r': '#A51931', 'w': '#F4F5F8', 'b': '#2D2A4A'},
    (g) => _hs(g, ['r', 'w', 'b', 'w', 'r'], [1, 1, 2, 1, 1]),
  ),
  (
    'id',
    'as',
    '인도네시아',
    'Indonesia',
    {'r': '#CE1126', 'w': _white},
    (g) => _hs(g, ['r', 'w']),
  ),
  (
    'tr',
    'as',
    '튀르키예',
    'Türkiye',
    {'r': '#E30A17', 'w': _white},
    (g) {
      g.each((x, y) => true, 'r');
      _crescent(g, 11, 10, 5, 'w', 'r');
      _star(g, 17.2, 10, 2.4, 'w', 0);
    },
  ),
  (
    'pk',
    'as',
    '파키스탄',
    'Pakistan',
    {'w': _white, 'g': '#01411C'},
    (g) {
      _vs(g, ['w', 'g'], [1, 3]);
      _crescent(g, 18, 10.5, 5, 'w', 'g', 0.25);
      _star(g, 21, 7.5, 1.8, 'w', -math.pi / 4);
    },
  ),
  (
    'sg',
    'as',
    '싱가포르',
    'Singapore',
    {'r': '#EF3340', 'w': _white},
    (g) {
      _hs(g, ['r', 'w']);
      _crescent(g, 6, 5, 3.4, 'w', 'r', 0.3);
      for (var k = 0; k < 5; k++) {
        final a = -math.pi / 2 + k * 2 * math.pi / 5;
        _star(g, 10 + math.cos(a) * 2.2, 5 + math.sin(a) * 2.2, 0.85, 'w');
      }
    },
  ),
  (
    'la',
    'as',
    '라오스',
    'Laos',
    {'r': '#CE1126', 'b': '#002868', 'w': _white},
    (g) {
      _hs(g, ['r', 'b', 'r'], [1, 2, 1]);
      g.ell(15, 10, 4, 4, 'w');
    },
  ),
  (
    'mm',
    'as',
    '미얀마',
    'Myanmar',
    {'y': '#FECB00', 'g': '#34B233', 'r': '#EA2839', 'w': _white},
    (g) {
      _hs(g, ['y', 'g', 'r']);
      _star(g, 15, 10.8, 7.5, 'w');
    },
  ),
  (
    'np',
    'as',
    '네팔',
    'Nepal',
    {'r': '#DC143C', 'b': '#003893', 'w': _white},
    (g) {
      // 삼각 깃발 두 개를 겹친 모양 (바깥은 빈 칸)
      g.poly([(1, 0), (21, 10.5), (9, 10.5), (21, 20), (1, 20)], 'b');
      g.poly([(2.2, 2), (18, 9.6), (6.5, 9.6), (18, 19), (2.2, 19)], 'r');
      g.ell(6.5, 7, 2, 1.2, 'w');
      g.ell(6.5, 6, 2, 1.0, 'r');
      _star(g, 6.5, 14.5, 2.4, 'w');
    },
  ),
  (
    'il',
    'as',
    '이스라엘',
    'Israel',
    {'w': _white, 'b': '#0038B8'},
    (g) {
      g.each((x, y) => true, 'w');
      g.each((x, y) => (y > 1 && y < 3.5) || (y > 16.5 && y < 19), 'b');
      bool tri(double x, double y, bool up) {
        final cy = up ? 10.0 - 5.2 : 10.0 + 5.2, by = up ? 12.6 : 7.4;
        final t = (y - cy) / (by - cy);
        return t >= 0 && t <= 1 && (x - 15).abs() <= t * 4.5;
      }

      bool shrink(double x, double y, bool up) {
        final cy = up ? 10.0 - 3.6 : 10.0 + 3.6, by = up ? 11.8 : 8.2;
        final t = (y - cy) / (by - cy);
        return t >= 0 && t <= 1 && (x - 15).abs() <= t * 3.0;
      }

      g.each(
        (x, y) =>
            (tri(x, y, true) && !shrink(x, y, true)) ||
            (tri(x, y, false) && !shrink(x, y, false)),
        'b',
      );
    },
  ),
  (
    'qa',
    'as',
    '카타르',
    'Qatar',
    {'w': _white, 'm': '#8A1538'},
    (g) {
      g.each((x, y) => true, 'm');
      g.each((x, y) {
        final f = (y / (20 / 9)) % 1;
        final tooth = 9 + (f < 0.5 ? f : 1 - f) * 2 * 2.6;
        return x < tooth;
      }, 'w');
    },
  ),
  (
    'bh',
    'as',
    '바레인',
    'Bahrain',
    {'w': _white, 'r': '#CE1126'},
    (g) {
      g.each((x, y) => true, 'r');
      g.each((x, y) {
        final f = (y / 4) % 1;
        final tooth = 7 + (f < 0.5 ? f : 1 - f) * 2 * 3;
        return x < tooth;
      }, 'w');
    },
  ),
  (
    'kw',
    'as',
    '쿠웨이트',
    'Kuwait',
    {'g': '#007A3D', 'w': _white, 'r': '#CE1126', 'k': _black},
    (g) {
      _hs(g, ['g', 'w', 'r']);
      g.poly([(0, 0), (7.5, 6.7), (7.5, 13.3), (0, 20)], 'k');
    },
  ),
  (
    'ae',
    'as',
    '아랍에미리트',
    'United Arab Emirates',
    {'r': '#FF0000', 'g': '#00732F', 'w': _white, 'k': _black},
    (g) {
      _hs(g, ['g', 'w', 'k']);
      g.each((x, y) => x < 7.5, 'r');
    },
  ),
  (
    'ye',
    'as',
    '예멘',
    'Yemen',
    {'r': '#CE1126', 'w': _white, 'k': _black},
    (g) => _hs(g, ['r', 'w', 'k']),
  ),
  (
    'ph',
    'as',
    '필리핀',
    'Philippines',
    {'b': '#0038A8', 'r': '#CE1126', 'w': _white, 'y': '#FCD116'},
    (g) {
      _hs(g, ['b', 'r']);
      g.poly([(0, 0), (17, 10), (0, 20)], 'w');
      g.ell(6, 10, 2, 2, 'y');
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        g.each((x, y) {
          final dx = x - 6, dy = y - 10;
          final r = math.sqrt(dx * dx + dy * dy);
          final d =
              (math.atan2(dy, dx) - a + math.pi * 3) % (2 * math.pi) - math.pi;
          return r > 2 && r < 3.6 && d.abs() < 0.22;
        }, 'y');
      }
      for (final (sx, sy) in [(1.8, 2.6), (1.8, 17.4), (13.3, 10.0)]) {
        _star(g, sx, sy, 1.2, 'y');
      }
    },
  ),
  // ── 아프리카 ──
  (
    'ng',
    'af',
    '나이지리아',
    'Nigeria',
    {'g': '#008751', 'w': _white},
    (g) => _vs(g, ['g', 'w', 'g']),
  ),
  (
    'ci',
    'af',
    '코트디부아르',
    "Côte d'Ivoire",
    {'o': '#F77F00', 'w': _white, 'g': '#009E60'},
    (g) => _vs(g, ['o', 'w', 'g']),
  ),
  (
    'ml',
    'af',
    '말리',
    'Mali',
    {'g': '#14B53A', 'y': '#FCD116', 'r': '#CE1126'},
    (g) => _vs(g, ['g', 'y', 'r']),
  ),
  (
    'gn',
    'af',
    '기니',
    'Guinea',
    {'r': '#CE1126', 'y': '#FCD116', 'g': '#009460'},
    (g) => _vs(g, ['r', 'y', 'g']),
  ),
  (
    'td',
    'af',
    '차드',
    'Chad',
    {'b': '#002664', 'y': '#FECB00', 'r': '#C60C30'},
    (g) => _vs(g, ['b', 'y', 'r']),
  ),
  (
    'sn',
    'af',
    '세네갈',
    'Senegal',
    {'g': '#00853F', 'y': '#FDEF42', 'r': '#E31B23'},
    (g) {
      _vs(g, ['g', 'y', 'r']);
      _star(g, 15, 10.6, 4.4, 'g');
    },
  ),
  (
    'cm',
    'af',
    '카메룬',
    'Cameroon',
    {'g': '#007A5E', 'r': '#CE1126', 'y': '#FCD116'},
    (g) {
      _vs(g, ['g', 'r', 'y']);
      _star(g, 15, 10.6, 4.4, 'y');
    },
  ),
  (
    'gh',
    'af',
    '가나',
    'Ghana',
    {'r': '#CE1126', 'y': '#FCD116', 'g': '#006B3F', 'k': _black},
    (g) {
      _hs(g, ['r', 'y', 'g']);
      _star(g, 15, 10.6, 4.4, 'k');
    },
  ),
  (
    'et',
    'af',
    '에티오피아',
    'Ethiopia',
    {'g': '#078930', 'y': '#FCDD09', 'r': '#DA121A', 'b': '#0F47AF'},
    (g) {
      _hs(g, ['g', 'y', 'r']);
      g.ell(15, 10, 5.4, 5.4, 'b');
      _star(g, 15, 10.5, 4.4, 'y');
    },
  ),
  (
    'rw',
    'af',
    '르완다',
    'Rwanda',
    {'b': '#00A1DE', 'y': '#FAD201', 'g': '#20603D'},
    (g) {
      _hs(g, ['b', 'y', 'g'], [2, 1, 1]);
      g.ell(24, 5, 1.8, 1.8, 'y');
      for (var k = 0; k < 24; k++) {
        final a = k * math.pi / 12;
        g.ell(24 + math.cos(a) * 3, 5 + math.sin(a) * 3, 0.5, 0.5, 'y');
      }
    },
  ),
  (
    'bj',
    'af',
    '베냉',
    'Benin',
    {'g': '#008751', 'y': '#FCD116', 'r': '#E8112D'},
    (g) {
      _hs(g, ['y', 'r']);
      g.each((x, y) => x < 12, 'g');
    },
  ),
  (
    'mg',
    'af',
    '마다가스카르',
    'Madagascar',
    {'w': _white, 'r': '#FC3D32', 'g': '#007E3A'},
    (g) {
      _hs(g, ['r', 'g']);
      g.each((x, y) => x < 10, 'w');
    },
  ),
  (
    'bf',
    'af',
    '부르키나파소',
    'Burkina Faso',
    {'r': '#EF2B2D', 'g': '#009E49', 'y': '#FCD116'},
    (g) {
      _hs(g, ['r', 'g']);
      _star(g, 15, 10.6, 4.4, 'y');
    },
  ),
  (
    'tg',
    'af',
    '토고',
    'Togo',
    {'g': '#006A4E', 'y': '#FFCE00', 'r': '#D21034', 'w': _white},
    (g) {
      _hs(g, ['g', 'y', 'g', 'y', 'g']);
      g.each((x, y) => x < 12 && y < 12, 'r');
      _star(g, 6, 6.4, 4.2, 'w');
    },
  ),
  (
    'ma',
    'af',
    '모로코',
    'Morocco',
    {'r': '#C1272D', 'g': '#006233'},
    (g) {
      g.each((x, y) => true, 'r');
      final pts = [
        for (var k = 0; k < 5; k++)
          (
            15 + math.cos(-math.pi / 2 + k * 4 * math.pi / 5) * 5.2,
            10.4 + math.sin(-math.pi / 2 + k * 4 * math.pi / 5) * 5.2,
          ),
      ];
      for (var k = 0; k < 5; k++) {
        final (ax, ay) = pts[k];
        final (bx, by) = pts[(k + 1) % 5];
        g.each((x, y) {
          final dx = bx - ax, dy = by - ay;
          final t = (((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy))
              .clamp(0.0, 1.0);
          return math.pow(ax + t * dx - x, 2) + math.pow(ay + t * dy - y, 2) <
              0.36;
        }, 'g');
      }
    },
  ),
  (
    'tn',
    'af',
    '튀니지',
    'Tunisia',
    {'r': '#E70013', 'w': _white},
    (g) {
      g.each((x, y) => true, 'r');
      g.ell(15, 10, 5.5, 5.5, 'w');
      _crescent(g, 14.5, 10, 4, 'r', 'w', 0.35);
      _star(g, 16.8, 10, 1.8, 'r', 0);
    },
  ),
  (
    'dz',
    'af',
    '알제리',
    'Algeria',
    {'g': '#006233', 'w': _white, 'r': '#D21034'},
    (g) {
      _vs(g, ['g', 'w']);
      _crescent(g, 14.5, 10, 5, 'r', 'w', 0.35);
      // 반쪽이 초록 위에 있으므로 지운 자리를 원래 색으로
      g.each((x, y) => x < 15 && g.at(x.floor(), y.floor()) == 'w', 'g');
      _star(g, 17.2, 10, 2, 'r', 0);
    },
  ),
  (
    'ne',
    'af',
    '니제르',
    'Niger',
    {'o': '#E05206', 'w': _white, 'g': '#0DB02B'},
    (g) {
      _hs(g, ['o', 'w', 'g']);
      g.ell(15, 10, 2.4, 2.4, 'o');
    },
  ),
  (
    'sl',
    'af',
    '시에라리온',
    'Sierra Leone',
    {'g': '#1EB53A', 'w': _white, 'b': '#0072C6'},
    (g) => _hs(g, ['g', 'w', 'b']),
  ),
  (
    'ga',
    'af',
    '가봉',
    'Gabon',
    {'g': '#009E60', 'y': '#FCD116', 'b': '#3A75C4'},
    (g) => _hs(g, ['g', 'y', 'b']),
  ),
  (
    'bw',
    'af',
    '보츠와나',
    'Botswana',
    {'b': '#75AADB', 'w': _white, 'k': _black},
    (g) {
      _hs(g, ['b', 'w', 'k', 'w', 'b'], [9, 1, 4, 1, 9]);
    },
  ),
  (
    'za',
    'af',
    '남아프리카공화국',
    'South Africa',
    {
      'r': '#E03C31',
      'b': '#001489',
      'g': '#007749',
      'w': _white,
      'y': '#FFB81C',
      'k': _black,
    },
    (g) {
      _hs(g, ['r', 'b']);
      bool yShape(double x, double y, double t) =>
          (x > 13 && (y - 10).abs() < t) ||
          (x <= 13.5 &&
              ((y - x * 10 / 13.5).abs() < t * 1.25 ||
                  (y - (20 - x * 10 / 13.5)).abs() < t * 1.25));
      g.each((x, y) => yShape(x, y, 4), 'w');
      g.each((x, y) => yShape(x, y, 2.6), 'g');
      g.poly([(0, 2.5), (9, 10), (0, 17.5)], 'y');
      g.poly([(0, 4.5), (6.8, 10), (0, 15.5)], 'k');
    },
  ),
  (
    'tz',
    'af',
    '탄자니아',
    'Tanzania',
    {'g': '#1EB53A', 'b': '#00A3DD', 'y': '#FCD116', 'k': _black},
    (g) {
      g.each((x, y) => y < 20 - x * 20 / 30, 'g');
      g.each((x, y) => y >= 20 - x * 20 / 30, 'b');
      g.each((x, y) => (y - (20 - x * 20 / 30)).abs() < 4.2, 'y');
      g.each((x, y) => (y - (20 - x * 20 / 30)).abs() < 3, 'k');
    },
  ),
  (
    'cg',
    'af',
    '콩고 공화국',
    'Republic of the Congo',
    {'g': '#009543', 'y': '#FBDE4A', 'r': '#DC241F'},
    (g) {
      g.each((x, y) => y + x * 20 / 30 < 15, 'g');
      g.each((x, y) => y + x * 20 / 30 >= 15, 'y');
      g.each((x, y) => y + x * 20 / 30 >= 25, 'r');
    },
  ),
  (
    'sc',
    'af',
    '세이셸',
    'Seychelles',
    {
      'b': '#003F87',
      'y': '#FCD856',
      'r': '#D62828',
      'w': _white,
      'g': '#007A3D',
    },
    (g) {
      g.each((x, y) {
        final a = math.atan2(20 - y, x);
        return a > math.pi * 0.36;
      }, 'b');
      g.each((x, y) {
        final a = math.atan2(20 - y, x);
        return a <= math.pi * 0.36 && a > math.pi * 0.2;
      }, 'y');
      g.each((x, y) {
        final a = math.atan2(20 - y, x);
        return a <= math.pi * 0.2 && a > math.pi * 0.12;
      }, 'r');
      g.each((x, y) {
        final a = math.atan2(20 - y, x);
        return a <= math.pi * 0.12 && a > math.pi * 0.06;
      }, 'w');
      g.each((x, y) => math.atan2(20 - y, x) <= math.pi * 0.06, 'g');
    },
  ),
  (
    'mu',
    'af',
    '모리셔스',
    'Mauritius',
    {'r': '#EA2839', 'b': '#1A206D', 'y': '#FFD500', 'g': '#00A551'},
    (g) => _hs(g, ['r', 'b', 'y', 'g']),
  ),
  (
    'lr',
    'af',
    '라이베리아',
    'Liberia',
    {'r': '#BF0A30', 'w': _white, 'b': '#002868'},
    (g) {
      _hs(g, ['r', 'w', 'r', 'w', 'r', 'w', 'r', 'w', 'r', 'w', 'r']);
      g.each((x, y) => x < 10 && y < 9.1, 'b');
      _star(g, 5, 5.0, 3.8, 'w');
    },
  ),
  // ── 아메리카 ──
  (
    'ca',
    'am',
    '캐나다',
    'Canada',
    {'r': '#D80621', 'w': _white},
    (g) {
      _vs(g, ['r', 'w', 'r'], [1, 2, 1]);
      // 단풍잎 (단순화)
      g.poly([
        (15, 3.2),
        (16.2, 5.6),
        (17.6, 4.8),
        (17.2, 8.2),
        (19.4, 6.6),
        (20, 7.8),
        (21.6, 7.4),
        (21, 9.6),
        (22, 10.2),
        (18.4, 13.2),
        (18.8, 14.4),
        (15.5, 13.8),
        (15.5, 17),
        (14.5, 17),
        (14.5, 13.8),
        (11.2, 14.4),
        (11.6, 13.2),
        (8, 10.2),
        (9, 9.6),
        (8.4, 7.4),
        (10, 7.8),
        (10.6, 6.6),
        (12.8, 8.2),
        (12.4, 4.8),
        (13.8, 5.6),
      ], 'r');
    },
  ),
  (
    'us',
    'am',
    '미국',
    'United States',
    {'r': '#B22234', 'w': _white, 'b': '#3C3B6E'},
    (g) {
      g.each((x, y) => ((y * 13 / 20).floor()).isEven, 'r');
      g.each((x, y) => ((y * 13 / 20).floor()).isOdd, 'w');
      g.each((x, y) => x < 12 && y < 10.8, 'b');
      for (var sy = 1; sy < 10; sy += 2) {
        for (var sx = (sy % 4 == 1 ? 1 : 2); sx < 12; sx += 2) {
          g.set(sx, sy, 'w');
        }
      }
    },
  ),
  (
    'br',
    'am',
    '브라질',
    'Brazil',
    {'g': '#009C3B', 'y': '#FFDF00', 'b': '#002776', 'w': _white},
    (g) {
      g.each((x, y) => true, 'g');
      g.poly([(15, 1.6), (27.5, 10), (15, 18.4), (2.5, 10)], 'y');
      g.ell(15, 10, 5.2, 5.2, 'b');
      g.each(
        (x, y) =>
            math.pow(x - 15, 2) + math.pow(y - 10, 2) <= 27 &&
            ((y - (9.5 + (x - 15) * 0.18)).abs() < 0.7),
        'w',
      );
    },
  ),
  (
    'ar',
    'am',
    '아르헨티나',
    'Argentina',
    {'b': '#74ACDF', 'w': _white, 'y': '#F6B40E'},
    (g) {
      _hs(g, ['b', 'w', 'b']);
      g.ell(15, 10, 2.8, 2.8, 'y');
    },
  ),
  (
    'co',
    'am',
    '콜롬비아',
    'Colombia',
    {'y': '#FCD116', 'b': '#003893', 'r': '#CE1126'},
    (g) => _hs(g, ['y', 'b', 'r'], [2, 1, 1]),
  ),
  (
    'pe',
    'am',
    '페루',
    'Peru',
    {'r': '#D91023', 'w': _white},
    (g) => _vs(g, ['r', 'w', 'r']),
  ),
  (
    'bo',
    'am',
    '볼리비아',
    'Bolivia',
    {'r': '#D52B1E', 'y': '#F9E300', 'g': '#007934'},
    (g) => _hs(g, ['r', 'y', 'g']),
  ),
  (
    'cl',
    'am',
    '칠레',
    'Chile',
    {'w': _white, 'r': '#D52B1E', 'b': '#0039A6'},
    (g) {
      _hs(g, ['w', 'r']);
      g.each((x, y) => x < 10 && y < 10, 'b');
      _star(g, 5, 5.5, 3.8, 'w');
    },
  ),
  (
    'cu',
    'am',
    '쿠바',
    'Cuba',
    {'b': '#002A8F', 'w': _white, 'r': '#CF142B'},
    (g) {
      _hs(g, ['b', 'w', 'b', 'w', 'b']);
      g.poly([(0, 0), (13, 10), (0, 20)], 'r');
      _star(g, 4.6, 10.5, 3.6, 'w');
    },
  ),
  (
    'bs',
    'am',
    '바하마',
    'Bahamas',
    {'a': '#00778B', 'y': '#FFC72C', 'k': _black},
    (g) {
      _hs(g, ['a', 'y', 'a']);
      g.poly([(0, 0), (11, 10), (0, 20)], 'k');
    },
  ),
  (
    'jm',
    'am',
    '자메이카',
    'Jamaica',
    {'g': '#009B3A', 'y': '#FED100', 'k': _black},
    (g) {
      g.each((x, y) => true, 'g');
      g.poly([(0, 0), (15, 10), (0, 20)], 'k');
      g.poly([(30, 0), (15, 10), (30, 20)], 'k');
      g.each(
        (x, y) => (y - x * 2 / 3).abs() < 2 || (y - (20 - x * 2 / 3)).abs() < 2,
        'y',
      );
    },
  ),
  (
    'pa',
    'am',
    '파나마',
    'Panama',
    {'w': _white, 'r': '#DA121A', 'b': '#072357'},
    (g) {
      g.each((x, y) => true, 'w');
      g.each((x, y) => x >= 15 && y < 10, 'r');
      g.each((x, y) => x < 15 && y >= 10, 'b');
      _star(g, 7.5, 5.4, 3.4, 'b');
      _star(g, 22.5, 15.4, 3.4, 'r');
    },
  ),
  (
    'cr',
    'am',
    '코스타리카',
    'Costa Rica',
    {'b': '#002B7F', 'w': _white, 'r': '#CE1126'},
    (g) => _hs(g, ['b', 'w', 'r', 'w', 'b'], [1, 1, 2, 1, 1]),
  ),
  (
    'gy',
    'am',
    '가이아나',
    'Guyana',
    {'g': '#009E49', 'w': _white, 'y': '#FCD116', 'k': _black, 'r': '#CE1126'},
    (g) {
      g.each((x, y) => true, 'g');
      g.poly([(0, 0), (30, 10), (0, 20)], 'w');
      g.poly([(0, 1), (28, 10), (0, 19)], 'y');
      g.poly([(0, 0), (15, 10), (0, 20)], 'k');
      g.poly([(0, 1.5), (13, 10), (0, 18.5)], 'r');
    },
  ),
  (
    'tt',
    'am',
    '트리니다드 토바고',
    'Trinidad and Tobago',
    {'r': '#CE1126', 'w': _white, 'k': _black},
    (g) {
      g.each((x, y) => true, 'r');
      g.each((x, y) => (y - x * 20 / 30).abs() < 4.2, 'w');
      g.each((x, y) => (y - x * 20 / 30).abs() < 3, 'k');
    },
  ),
  (
    've',
    'am',
    '베네수엘라',
    'Venezuela',
    {'y': '#FFCC00', 'b': '#00247D', 'r': '#CF142B', 'w': _white},
    (g) {
      _hs(g, ['y', 'b', 'r']);
      for (var k = 0; k < 8; k++) {
        final a = math.pi * (1.15 + k * 0.7 / 7);
        g.ell(15 + math.cos(a) * 4.6, 11.5 + math.sin(a) * 4.6, 0.6, 0.6, 'w');
      }
    },
  ),
  (
    'uy',
    'am',
    '우루과이',
    'Uruguay',
    {'w': _white, 'b': '#0038A8', 'y': '#FCD116'},
    (g) {
      _hs(g, ['w', 'b', 'w', 'b', 'w', 'b', 'w', 'b', 'w']);
      g.each((x, y) => x < 11 && y < 11.2, 'w');
      g.ell(5.5, 5.6, 2.2, 2.2, 'y');
      for (var k = 0; k < 16; k++) {
        final a = k * math.pi / 8;
        g.ell(
          5.5 + math.cos(a) * 3.4,
          5.6 + math.sin(a) * 3.4,
          0.55,
          0.55,
          'y',
        );
      }
    },
  ),
  // ── 오세아니아 ──
  (
    'to',
    'oc',
    '통가',
    'Tonga',
    {'r': '#C10000', 'w': _white},
    (g) {
      g.each((x, y) => true, 'r');
      g.each((x, y) => x < 13 && y < 10, 'w');
      g.each(
        (x, y) =>
            x < 13 &&
            y < 10 &&
            (((x - 6.5).abs() < 1.2 && (y - 5).abs() < 3.8) ||
                ((y - 5).abs() < 1.2 && (x - 6.5).abs() < 3.8)),
        'r',
      );
    },
  ),
  (
    'ws',
    'oc',
    '사모아',
    'Samoa',
    {'r': '#CE1126', 'b': '#002B7F', 'w': _white},
    (g) {
      g.each((x, y) => true, 'r');
      g.each((x, y) => x < 14 && y < 10, 'b');
      for (final (sx, sy, r) in [
        (7.0, 1.8, 1.3),
        (10.0, 4.4, 1.3),
        (3.8, 5.0, 1.3),
        (7.0, 8.0, 1.5),
        (8.6, 5.7, 0.8),
      ]) {
        _star(g, sx, sy, r, 'w');
      }
    },
  ),
  (
    'fm',
    'oc',
    '미크로네시아',
    'Micronesia',
    {'b': '#75B2DD', 'w': _white},
    (g) {
      g.each((x, y) => true, 'b');
      for (final (sx, sy) in [
        (15.0, 4.6),
        (20.4, 10.0),
        (15.0, 15.4),
        (9.6, 10.0),
      ]) {
        _star(g, sx, sy, 2.2, 'w');
      }
    },
  ),
  (
    'nr',
    'oc',
    '나우루',
    'Nauru',
    {'b': '#002B7F', 'y': '#FFC61E', 'w': _white},
    (g) {
      g.each((x, y) => true, 'b');
      g.each((x, y) => (y - 10).abs() < 0.8, 'y');
      g.each((x, y) {
        final dx = x - 7.5, dy = y - 14.5;
        final a = math.atan2(dy, dx);
        final r = 2.6 * (0.55 + 0.45 * math.pow((math.cos(6 * a)).abs(), 2));
        return dx * dx + dy * dy <= r * r;
      }, 'w');
    },
  ),
  (
    'pw',
    'oc',
    '팔라우',
    'Palau',
    {'b': '#4AADD6', 'y': '#FFDE00'},
    (g) {
      g.each((x, y) => true, 'b');
      g.ell(13, 10, 6, 6, 'y');
    },
  ),
  (
    'sb',
    'oc',
    '솔로몬 제도',
    'Solomon Islands',
    {'b': '#0051BA', 'g': '#215B33', 'y': '#FCD116', 'w': _white},
    (g) {
      g.each((x, y) => y < 20 - x * 20 / 30, 'b');
      g.each((x, y) => y >= 20 - x * 20 / 30, 'g');
      g.each((x, y) => (y - (20 - x * 20 / 30)).abs() < 1.3, 'y');
      for (final (sx, sy) in [
        (3.0, 2.6),
        (9.0, 2.6),
        (6.0, 5.0),
        (3.0, 7.4),
        (9.0, 7.4),
      ]) {
        _star(g, sx, sy, 1.2, 'w');
      }
    },
  ),
  (
    'mh',
    'oc',
    '마셜 제도',
    'Marshall Islands',
    {'b': '#003893', 'o': '#DD7500', 'w': _white},
    (g) {
      g.each((x, y) => true, 'b');
      g.each((x, y) => (y - (20 - x * 0.5) + 0.9).abs() < 1.0 && y > 2, 'o');
      g.each((x, y) => (y - (20 - x * 0.5) - 1.1).abs() < 1.0 && y > 2, 'w');
      g.each((x, y) {
        final dx = x - 6, dy = y - 6;
        final a = math.atan2(dy, dx);
        final r = 3.6 * (0.35 + 0.65 * math.pow((math.cos(12 * a)).abs(), 4));
        return dx * dx + dy * dy <= r * r;
      }, 'w');
    },
  ),
  (
    'au',
    'oc',
    '오스트레일리아',
    'Australia',
    {'b': '#012169', 'w': _white, 'r': '#E4002B'},
    (g) {
      g.each((x, y) => true, 'b');
      _ujack(g, 0, 0, 15, 10);
      _star(g, 7.5, 15, 2.3, 'w');
      for (final (sx, sy, r) in [
        (23.0, 3.0, 1.2),
        (19.0, 9.0, 1.2),
        (26.5, 8.0, 1.2),
        (23.0, 17.0, 1.3),
        (24.8, 11.4, 0.7),
      ]) {
        _star(g, sx, sy, r, 'w');
      }
    },
  ),
  (
    'nz',
    'oc',
    '뉴질랜드',
    'New Zealand',
    {'b': '#012169', 'w': _white, 'r': '#C8102E'},
    (g) {
      g.each((x, y) => true, 'b');
      _ujack(g, 0, 0, 15, 10);
      for (final (sx, sy) in [
        (23.0, 3.5),
        (20.0, 9.0),
        (26.0, 8.0),
        (23.0, 16.5),
      ]) {
        _star(g, sx, sy, 1.7, 'w');
        _star(g, sx, sy, 0.9, 'r');
      }
    },
  ),
];

List<ArtSource> flagArts() => [
  for (final (code, region, ko, en, pal, draw) in _flags())
    () {
      final g = _flag();
      draw(g);
      return makeArt('f_${region}_$code', '$ko 국기', 'Flag of $en', pal, g);
    }(),
];
