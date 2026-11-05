// 장난감 그림 (2026-11-05). 이름은 t_ 로 시작한다.
// 26×26, 장난감 40가지 × 색 4가지 = 160장. 배경 'a' 와 바닥 'b' 위에 장난감 하나를 크게 그린다.
// 팔레트: a 배경, b 바닥, c 주색, d 보조색, e 어두운 선, f 흰색(또는 살색·밝은 색) — 6색 이하.
// 모두 시드 고정이라 언제 돌려도 같다.
import 'dart:math' as math;

import 'package:bloom_wave/domain/generator.dart';

import 'art_gen.dart';
import 'art_source.dart';

// ───────── 도구 ─────────

/// 네 귀퉁이를 반지름 r 로 둥글게 깎는다
void _round(Grid g, double r) {
  for (var y = 0; y < g.h; y++) {
    for (var x = 0; x < g.w; x++) {
      final cx = x + 0.5, cy = y + 0.5;
      final dx = cx < r ? r - cx : (cx > g.w - r ? cx - (g.w - r) : 0.0);
      final dy = cy < r ? r - cy : (cy > g.h - r ? cy - (g.h - r) : 0.0);
      if (dx > 0 && dy > 0 && dx * dx + dy * dy > r * r) {
        g.set(x, y, '.');
      }
    }
  }
}

/// 굵은 선분
void _line(
  Grid g,
  double x0,
  double y0,
  double x1,
  double y1,
  double w,
  String ch,
) {
  final dx = x1 - x0, dy = y1 - y0;
  final len2 = dx * dx + dy * dy;
  g.each((x, y) {
    final t = len2 == 0
        ? 0.0
        : (((x - x0) * dx + (y - y0) * dy) / len2).clamp(0.0, 1.0);
    final px = x0 + t * dx - x, py = y0 + t * dy - y;
    return px * px + py * py <= w * w / 4;
  }, ch);
}

/// 고리 (반지름 r, 굵기 w)
void _ring(Grid g, double cx, double cy, double r, double w, String ch) =>
    g.each((x, y) {
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      return (d - r).abs() <= w / 2;
    }, ch);

String _hex(int r, int gr, int b) =>
    '#${[r, gr, b].map((v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

/// 색 섞기 (t = 0 이면 a, 1 이면 b)
String _mix(String a, String b, double t) {
  int c(String h, int i) =>
      int.parse(h.substring(1 + i * 2, 3 + i * 2), radix: 16);
  int m(int i) => (c(a, i) + (c(b, i) - c(a, i)) * t).round();
  return _hex(m(0), m(1), m(2));
}

/// 5×5 글자 (쌓기 블록)
const _glyphs = {
  'A': ['.###.', '#...#', '#####', '#...#', '#...#'],
  'B': ['####.', '#...#', '####.', '#...#', '####.'],
  'C': ['.####', '#....', '#....', '#....', '.####'],
  '1': ['..#..', '.##..', '..#..', '..#..', '.###.'],
  '2': ['####.', '....#', '.###.', '#....', '#####'],
  '3': ['####.', '....#', '.###.', '....#', '####.'],
};

void _glyph(Grid g, String ch, int x0, int y0, String col) {
  final rows = _glyphs[ch]!;
  for (var y = 0; y < 5; y++) {
    for (var x = 0; x < 5; x++) {
      if (rows[y][x] == '#') {
        g.set(x0 + x, y0 + y, col);
      }
    }
  }
}

typedef _Rng = double Function();

// ───────── 장난감 40가지 ─────────
// 바닥은 22행부터. 장난감은 21행에 닿게 세운다. 가운데는 x = 13.0 (12·13번 칸 사이).

void _bear(Grid g, _Rng r, int v) {
  g.ell(6.5, 13.5, 2.2, 3.2, 'c');
  g.ell(19.5, 13.5, 2.2, 3.2, 'c');
  g.ell(9, 19.5, 3, 2.4, 'c');
  g.ell(17, 19.5, 3, 2.4, 'c');
  g.ell(9, 20, 1.6, 1.3, 'f');
  g.ell(17, 20, 1.6, 1.3, 'f');
  g.ell(13, 15.5, 6, 5.5, 'c');
  g.ell(13, 16, 3.6, 3.6, 'f');
  g.ell(7.5, 3.5, 2.4, 2.4, 'c');
  g.ell(18.5, 3.5, 2.4, 2.4, 'c');
  g.ell(7.5, 3.5, 1.2, 1.2, 'f');
  g.ell(18.5, 3.5, 1.2, 1.2, 'f');
  g.ell(13, 7.5, 6, 5, 'c');
  g.ell(13, 9.5, 2.8, 2.1, 'f');
  g.rect(12, 8, 13, 8, 'e');
  g.rect(12, 9, 13, 9, 'e');
  g.set(10, 6, 'e');
  g.set(15, 6, 'e');
  g.set(11, 10, 'e');
  g.set(14, 10, 'e');
  g.rect(12, 10, 13, 10, 'e');
  g.poly([(8.5, 11.2), (13, 13.2), (8.5, 15.2)], 'd');
  g.poly([(17.5, 11.2), (13, 13.2), (17.5, 15.2)], 'd');
  g.ell(13, 13.2, 1.2, 1.2, 'd');
}

void _robot(Grid g, _Rng r, int v) {
  _line(g, 13, 0.8, 13, 3, 0.9, 'e');
  g.ell(13, 1.2, 1.3, 1.1, 'd');
  g.rect(7, 3, 18, 9, 'c');
  g.rect(9, 5, 11, 6, 'f');
  g.rect(14, 5, 16, 6, 'f');
  g.set(10, 6, 'e');
  g.set(15, 6, 'e');
  g.rect(9, 8, 16, 8, 'e');
  for (var x = 10; x <= 16; x += 2) {
    g.set(x, 8, 'f');
  }
  g.rect(5, 4, 6, 7, 'd');
  g.rect(19, 4, 20, 7, 'd');
  g.rect(11, 10, 14, 10, 'e');
  g.rect(6, 11, 19, 18, 'c');
  g.rect(8, 12, 17, 16, 'f');
  g.ell(10.5, 14.5, 1.2, 1.2, 'd');
  g.ell(15, 14.5, 1.6, 1.6, 'e');
  g.ell(15, 14.5, 0.8, 0.8, 'd');
  g.rect(8, 17, 17, 17, 'e');
  g.rect(3, 11, 4, 17, 'd');
  g.rect(21, 11, 22, 17, 'd');
  g.rect(2, 18, 5, 19, 'e');
  g.rect(20, 18, 23, 19, 'e');
  g.set(3, 19, 'a');
  g.set(4, 19, 'a');
  g.set(21, 19, 'a');
  g.set(22, 19, 'a');
  g.rect(8, 19, 11, 20, 'e');
  g.rect(14, 19, 17, 20, 'e');
  g.rect(7, 21, 12, 21, 'd');
  g.rect(13, 21, 18, 21, 'd');
}

void _rockingHorse(Grid g, _Rng r, int v) {
  g.each((x, y) {
    final d = math.sqrt(math.pow(x - 13, 2) + math.pow(y + 1, 2));
    return (d - 21.6).abs() < 0.95 && x > 1 && x < 25;
  }, 'd');
  for (final (x0, x1) in [
    (7.5, 5.5),
    (10.0, 9.5),
    (16.0, 16.5),
    (18.5, 20.5),
  ]) {
    _line(g, x0, 12, x1, 19, 1.7, 'c');
  }
  _line(g, 6, 9.5, 2.5, 14.5, 2.0, 'e');
  g.ell(12.5, 10.5, 7.5, 3.4, 'c');
  g.poly([(15, 10), (18, 3.5), (21.5, 5), (20, 11)], 'c');
  g.ell(20.5, 4.4, 3.4, 2.2, 'c');
  g.ell(23, 5.8, 1.8, 1.6, 'c');
  g.poly([(18.4, 3.2), (18.8, 0.4), (20.2, 2.8)], 'c');
  g.set(20, 4, 'e');
  g.set(23, 6, 'e');
  _line(g, 18.2, 2.6, 15.4, 9.6, 1.5, 'e');
  g.rect(10, 7, 14, 8, 'd');
  g.rect(11, 9, 13, 10, 'f');
  _line(g, 19.8, 5.6, 22.4, 7.4, 0.8, 'f');
}

void _top(Grid g, _Rng r, int v) {
  g.ell(13, 10.5, 10, 3.5, 'c');
  g.poly([(3.2, 10.5), (22.8, 10.5), (13, 21.8)], 'c');
  g.recolor('c', 'd', (x, y) => y >= 11 && y <= 12);
  g.recolor('c', 'f', (x, y) => y >= 15 && y <= 15);
  g.recolor('c', 'd', (x, y) => y >= 17 && y <= 18);
  g.recolor('c', 'f', (x, y) => y == 8 && (x - 13).abs() < 7);
  g.rect(12, 2, 13, 8, 'e');
  g.ell(13, 2, 1.8, 1.2, 'd');
  _line(g, 0.8, 14, 2.5, 14, 0.8, 'e');
  _line(g, 0.8, 17, 3.5, 17, 0.8, 'e');
  _line(g, 23.5, 14, 25.2, 14, 0.8, 'e');
  _line(g, 22.5, 17, 25.2, 17, 0.8, 'e');
}

void _yoyo(Grid g, _Rng r, int v) {
  _line(g, 13, 2.5, 13, 9, 0.8, 'e');
  _ring(g, 13, 2.5, 1.5, 0.9, 'e');
  g.ell(13, 13.5, 8.6, 8.6, 'c');
  _ring(g, 13, 13.5, 6.2, 1.1, 'e');
  g.ell(13, 13.5, 5.4, 5.4, 'd');
  g.ell(13, 13.5, 2.4, 2.4, 'f');
  g.ell(13, 13.5, 1, 1, 'e');
  g.ell(8.3, 9.3, 1.3, 1, 'f');
  for (var k = 0; k < 6; k++) {
    final a = k * math.pi / 3 + 0.3;
    g.ell(13 + math.cos(a) * 4, 13.5 + math.sin(a) * 4, 0.75, 0.75, 'f');
  }
}

void _duck(Grid g, _Rng r, int v) {
  g.poly([(3, 11), (5, 7.5), (9, 12)], 'c');
  g.ell(12, 15.5, 9, 5.6, 'c');
  g.ell(16, 7.6, 4.8, 4.5, 'c');
  g.ell(21.5, 9.2, 2.8, 1.3, 'd');
  g.rect(19, 9, 23, 9, 'e');
  g.ell(17.2, 6.5, 1, 1, 'e');
  g.set(17, 6, 'f');
  g.ell(10.5, 15, 4.5, 2.8, 'e');
  g.ell(10.8, 14.6, 3.8, 2.1, 'c');
  g.ell(9, 10, 1, 0.8, 'f');
  g.recolor('b', 'f', (x, y) => y == 22 && (x % 5 == 1 || x % 5 == 2));
  g.ell(23, 17, 1, 1, 'f');
  g.ell(2, 18, 0.8, 0.8, 'f');
}

void _train(Grid g, _Rng r, int v) {
  g.rect(0, 21, 25, 21, 'e');
  for (var x = 1; x < 26; x += 3) {
    g.set(x, 22, 'e');
  }
  g.ell(6, 1.8, 2, 1.4, 'f');
  g.ell(9.5, 1.2, 1.6, 1.1, 'f');
  g.rect(4, 6, 7, 10, 'e');
  g.rect(3, 4, 8, 5, 'e');
  g.rect(2, 10, 14, 16, 'c');
  g.rect(5, 10, 5, 16, 'd');
  g.rect(10, 10, 10, 16, 'd');
  g.rect(14, 5, 23, 16, 'c');
  g.rect(13, 4, 24, 5, 'e');
  g.rect(16, 7, 21, 10, 'f');
  g.rect(16, 12, 21, 14, 'd');
  g.rect(1, 17, 24, 17, 'e');
  g.poly([(0, 20.5), (2.5, 16.5), (2.5, 20.5)], 'd');
  g.ell(6, 18.6, 2.3, 2.3, 'e');
  g.ell(11, 18.6, 2.3, 2.3, 'e');
  g.ell(18.5, 17.5, 3.4, 3.4, 'e');
  g.ell(6, 18.6, 0.9, 0.9, 'd');
  g.ell(11, 18.6, 0.9, 0.9, 'd');
  g.ell(18.5, 17.5, 1.4, 1.4, 'd');
  g.ell(1.7, 12, 1, 1.2, 'f');
}

void _blocks(Grid g, _Rng r, int v) {
  const sets = [
    ['A', 'B', 'C'],
    ['1', '2', '3'],
    ['C', 'A', 'B'],
    ['3', '1', '2'],
  ];
  final s = sets[v % 4];
  for (final (x0, y0, body, ink, ch) in [
    (2, 12, 'c', 'f', s[0]),
    (14, 12, 'd', 'f', s[1]),
    (8, 2, 'f', 'c', s[2]),
  ]) {
    g.rect(x0, y0, x0 + 9, y0 + 9, 'e');
    g.rect(x0 + 1, y0 + 1, x0 + 8, y0 + 8, body);
    _glyph(g, ch, x0 + 3, y0 + 3, ink);
  }
}

void _kite(Grid g, _Rng r, int v) {
  g.ell(4, 4, 2.4, 1.2, 'f');
  g.ell(5.8, 3.4, 1.8, 1.2, 'f');
  g.ell(21, 18, 2.2, 1, 'f');
  final pts = [(14.0, 0.8), (21.5, 6.8), (14.0, 15.0), (6.5, 6.8)];
  g.poly(pts, 'c');
  g.poly([(14, 0.8), (14, 6.8), (6.5, 6.8)], 'd');
  g.poly([(14, 6.8), (21.5, 6.8), (14, 15)], 'd');
  _line(g, 14, 1.3, 14, 14.5, 0.8, 'e');
  _line(g, 7, 6.8, 21, 6.8, 0.8, 'e');
  const tail = [
    (14.0, 15.0),
    (11.5, 17.0),
    (9.0, 16.8),
    (6.5, 18.8),
    (4.0, 18.6),
    (2.0, 20.8),
  ];
  for (var k = 0; k + 1 < tail.length; k++) {
    final (x0, y0) = tail[k];
    final (x1, y1) = tail[k + 1];
    _line(g, x0, y0, x1, y1, 0.8, 'e');
  }
  for (var k = 1; k < tail.length - 1; k += 2) {
    final (nx, ny) = tail[k];
    final ch = k == 3 ? 'c' : 'd';
    g.poly([(nx - 1.8, ny - 1.4), (nx, ny), (nx - 1.8, ny + 1.4)], ch);
    g.poly([(nx + 1.8, ny - 1.4), (nx, ny), (nx + 1.8, ny + 1.4)], ch);
  }
  _line(g, 21.5, 6.8, 25.5, 12, 0.6, 'e');
}

void _beachBall(Grid g, _Rng r, int v) {
  g.ell(13, 21.6, 7.5, 1.1, 'e');
  const cx = 13.0, cy = 11.5, rad = 9.6;
  const cols = ['c', 'f', 'd', 'c', 'f', 'd'];
  g.each((x, y) => math.pow(x - cx, 2) + math.pow(y - cy, 2) <= rad * rad, 'c');
  for (var y = 0; y < 26; y++) {
    for (var x = 0; x < 26; x++) {
      if (g.at(x, y) != 'c') {
        continue;
      }
      final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      final half = math.sqrt(math.max(0.01, rad * rad - dy * dy));
      final u = (dx / half).clamp(-1.0, 1.0);
      final lon = math.asin(u) + math.pi / 2;
      final i = (lon / math.pi * 6).floor().clamp(0, 5);
      g.set(x, y, cols[i]);
    }
  }
  g.ell(13, 2.8, 2.2, 1.2, 'f');
  g.ell(13, 2.8, 1, 0.6, 'e');
  g.ell(8, 6.5, 1.2, 0.9, 'f');
}

void _ragDoll(Grid g, _Rng r, int v) {
  g.ell(6.5, 9.5, 1.8, 3.4, 'd');
  g.ell(19.5, 9.5, 1.8, 3.4, 'd');
  g.ell(13, 6.5, 6, 5.5, 'd');
  g.ell(13, 8, 4.5, 4, 'f');
  g.rect(9, 3, 16, 4, 'd');
  g.rect(10, 7, 11, 7, 'e');
  g.rect(14, 7, 15, 7, 'e');
  g.rect(12, 10, 13, 10, 'c');
  g.set(9, 9, 'c');
  g.set(16, 9, 'c');
  _line(g, 9.5, 13, 4.5, 17, 1.8, 'c');
  _line(g, 16.5, 13, 21.5, 17, 1.8, 'c');
  g.ell(4.2, 17.4, 1.2, 1.2, 'f');
  g.ell(21.8, 17.4, 1.2, 1.2, 'f');
  g.rect(10, 18, 11, 21, 'f');
  g.rect(14, 18, 15, 21, 'f');
  g.recolor('f', 'e', (x, y) => y >= 18 && y.isEven);
  g.poly([(9, 11.5), (17, 11.5), (20, 19), (6, 19)], 'c');
  g.rect(11, 12, 14, 12, 'f');
  for (var y = 14; y <= 18; y += 2) {
    for (var x = 7; x <= 18; x++) {
      if ((x + y ~/ 2) % 3 == 0 && g.at(x, y) == 'c') {
        g.set(x, y, 'f');
      }
    }
  }
}

void _car(Grid g, _Rng r, int v) {
  g.poly([(6, 12.5), (9, 6), (17, 6), (20.5, 12.5)], 'c');
  g.rect(1, 12, 24, 17, 'c');
  g.poly([(8, 11.5), (10, 7.4), (12.5, 7.4), (12.5, 11.5)], 'f');
  g.poly([(13.5, 7.4), (16.2, 7.4), (18.5, 11.5), (13.5, 11.5)], 'f');
  g.rect(13, 12, 13, 16, 'e');
  g.rect(14, 13, 15, 13, 'e');
  g.rect(1, 15, 24, 15, 'd');
  g.rect(23, 12, 24, 13, 'd');
  g.rect(1, 12, 1, 13, 'e');
  g.rect(0, 16, 1, 17, 'e');
  g.rect(24, 16, 25, 17, 'e');
  g.ell(6.5, 18, 3.3, 3.3, 'e');
  g.ell(19.5, 18, 3.3, 3.3, 'e');
  g.ell(6.5, 18, 1.4, 1.4, 'f');
  g.ell(19.5, 18, 1.4, 1.4, 'f');
}

void _drum(Grid g, _Rng r, int v) {
  _line(g, 3, 1.5, 11.5, 6.5, 1.2, 'b');
  _line(g, 23, 1.5, 14.5, 6.5, 1.2, 'b');
  g.ell(3, 1.5, 1.4, 1.4, 'e');
  g.ell(23, 1.5, 1.4, 1.4, 'e');
  g.ell(13, 18.4, 9.6, 3, 'd');
  g.each((x, y) => (x - 13).abs() < 9.6 && y > 9 && y < 18.4, 'c');
  g.each((x, y) => (x - 13).abs() < 9.6 && y > 16.4 && y < 18.4, 'd');
  g.ell(13, 9, 9.6, 3, 'd');
  g.ell(13, 8.6, 8.6, 2.3, 'f');
  g.each((x, y) {
    if (y < 11.5 || y > 16.3 || (x - 13).abs() > 9.3) {
      return false;
    }
    final t = ((x - 3.4) / 4.8) % 2;
    final wave = 11.7 + (t < 1 ? t : 2 - t) * 4.4;
    return (y - wave).abs() < 0.6;
  }, 'e');
}

void _jackBox(Grid g, _Rng r, int v) {
  g.poly([(4.5, 12.5), (0.8, 4.5), (3, 3.6), (6.6, 12)], 'd');
  for (var k = 0; k < 3; k++) {
    final y = 12.4 - k * 1.2;
    _line(g, 10.8, y, 15.2, y - 0.6, 0.8, 'e');
  }
  g.ell(13, 9, 4.6, 1.2, 'd');
  g.ell(8.6, 5.2, 1.6, 1.8, 'd');
  g.ell(17.4, 5.2, 1.6, 1.8, 'd');
  g.ell(13, 5.2, 4, 3.4, 'f');
  g.poly([(9.8, 3.2), (16.2, 3.2), (13, -0.8)], 'c');
  g.ell(13, 0.5, 0.9, 0.9, 'd');
  g.set(11, 4, 'e');
  g.set(14, 4, 'e');
  g.ell(13, 5.6, 1, 0.9, 'c');
  g.rect(11, 7, 14, 7, 'e');
  g.set(10, 6, 'e');
  g.set(15, 6, 'e');
  g.rect(5, 12, 20, 21, 'c');
  g.rect(5, 12, 20, 12, 'e');
  g.poly([(13, 13.5), (17, 17), (13, 20.5), (9, 17)], 'd');
  g.ell(13, 17, 1.4, 1.4, 'f');
  g.rect(21, 16, 23, 16, 'e');
  g.rect(23, 14, 23, 16, 'e');
  g.rect(23, 13, 24, 13, 'd');
}

void _cube(Grid g, _Rng r, int v) {
  // 비스듬히 본 큐브: 앞면 c, 윗면 f, 옆면 d. 스티커 몇 개는 섞여 있다
  const pick = ['c', 'd', 'f'];
  String sticker(String base) => r() < 0.2 ? pick[(r() * 3).floor()] : base;
  final front = [for (var k = 0; k < 9; k++) sticker('c')];
  final top = [for (var k = 0; k < 9; k++) sticker('f')];
  final side = [for (var k = 0; k < 9; k++) sticker('d')];
  for (var y = 0; y < 26; y++) {
    for (var x = 0; x < 26; x++) {
      if (x >= 3 && x <= 15 && y >= 9 && y <= 21) {
        final col = x - 3, row = y - 9;
        g.set(
          x,
          y,
          col % 4 == 0 || row % 4 == 0 ? 'e' : front[(row ~/ 4) * 3 + col ~/ 4],
        );
      } else if (y >= 2 && y <= 8) {
        final dd = 9 - y, col = x - dd - 3;
        if (col >= 0 && col <= 12) {
          g.set(
            x,
            y,
            dd.isOdd || col % 4 == 0 ? 'e' : top[(3 - dd ~/ 2) * 3 + col ~/ 4],
          );
        }
      }
      if (x >= 16 && x <= 22) {
        final dd = x - 15, row = y + dd - 9;
        if (row >= 0 && row <= 12) {
          g.set(
            x,
            y,
            dd.isOdd || row % 4 == 0 ? 'e' : side[(row ~/ 4) * 3 + dd ~/ 2 - 1],
          );
        }
      }
    }
  }
}

void _soldier(Grid g, _Rng r, int v) {
  g.ell(13, 3.5, 3.6, 3.6, 'e');
  g.rect(10, 3, 15, 7, 'e');
  g.rect(16, 1, 16, 4, 'd');
  g.ell(16.5, 1.2, 0.9, 1.2, 'c');
  g.rect(12, 5, 13, 6, 'd');
  g.rect(10, 8, 15, 10, 'f');
  g.set(11, 8, 'e');
  g.set(14, 8, 'e');
  g.set(10, 9, 'c');
  g.set(15, 9, 'c');
  g.rect(10, 10, 15, 10, 'd');
  g.rect(9, 11, 16, 16, 'c');
  g.rect(9, 11, 16, 11, 'd');
  g.rect(9, 15, 16, 15, 'd');
  for (var y = 12; y <= 14; y++) {
    g.set(12, y, 'd');
    g.set(13, y, 'd');
  }
  g.rect(12, 12, 13, 12, 'f');
  g.rect(7, 11, 8, 16, 'c');
  g.rect(17, 11, 18, 16, 'c');
  g.rect(7, 11, 8, 11, 'd');
  g.rect(17, 11, 18, 11, 'd');
  g.rect(7, 17, 8, 17, 'f');
  g.rect(17, 17, 18, 17, 'f');
  g.rect(9, 16, 12, 20, 'e');
  g.rect(13, 16, 16, 20, 'e');
  g.rect(9, 17, 9, 19, 'c');
  g.rect(16, 17, 16, 19, 'c');
  g.rect(12, 17, 13, 21, 'a');
  g.rect(8, 21, 11, 21, 'e');
  g.rect(14, 21, 17, 21, 'e');
  _line(g, 20.5, 3, 20.5, 17, 1, 'e');
  g.rect(20, 1, 21, 2, 'f');
}

void _plane(Grid g, _Rng r, int v) {
  g.ell(4, 3, 2.4, 1.2, 'f');
  g.ell(20, 2.2, 2.6, 1.2, 'f');
  _line(g, 9, 6, 9, 13.5, 0.8, 'e');
  _line(g, 16, 6, 16, 13.5, 0.8, 'e');
  g.rect(6, 5, 19, 6, 'd');
  g.poly([(1.5, 11), (1.5, 4.5), (3, 4.5), (6.5, 10)], 'c');
  g.ell(12.5, 11, 10.5, 3, 'c');
  g.rect(3, 10, 21, 10, 'f');
  g.ell(13.5, 8, 1.6, 1.4, 'e');
  g.rect(12, 9, 15, 9, 'e');
  g.rect(6, 13, 19, 14, 'd');
  g.ell(23, 11, 1.4, 1.4, 'd');
  g.ell(24.2, 11, 0.8, 5, 'e');
  _line(g, 11, 14, 9.5, 18.5, 0.8, 'e');
  _line(g, 15, 14, 16.5, 18.5, 0.8, 'e');
  g.ell(9.5, 19.2, 2, 2, 'e');
  g.ell(16.5, 19.2, 2, 2, 'e');
  g.ell(9.5, 19.2, 0.8, 0.8, 'f');
  g.ell(16.5, 19.2, 0.8, 0.8, 'f');
}

void _sailboat(Grid g, _Rng r, int v) {
  g.poly([(13.8, 2.5), (13.8, 15), (23, 15)], 'f');
  g.poly([(12.2, 4.5), (12.2, 15), (4, 15)], 'd');
  _line(g, 13, 1.5, 13, 16, 1, 'e');
  g.poly([(13.5, 0.5), (17, 1.6), (13.5, 2.7)], 'c');
  g.poly([(2, 15.5), (24, 15.5), (20, 21.4), (6, 21.4)], 'c');
  g.rect(3, 17, 22, 17, 'f');
  g.ell(9, 19.3, 0.9, 0.9, 'f');
  g.ell(13, 19.3, 0.9, 0.9, 'f');
  g.ell(17, 19.3, 0.9, 0.9, 'f');
  g.recolor('b', 'f', (x, y) => y == 23 && (x % 6 == 2 || x % 6 == 3));
  g.recolor('b', 'f', (x, y) => y == 25 && (x % 6 == 5 || x % 6 == 0));
}

void _dino(Grid g, _Rng r, int v) {
  _line(g, 6, 13, 1.2, 19, 2.6, 'c');
  _line(g, 2.5, 18, 0.5, 20, 1.4, 'c');
  for (var k = 0; k < 5; k++) {
    final x = 6.5 + k * 2.8;
    final y = 9.8 + 0.12 * math.pow(x - 12, 2) * 0.5;
    g.poly([(x - 1.4, y + 1.8), (x, y - 1.6), (x + 1.4, y + 1.8)], 'd');
  }
  g.ell(12, 14.5, 7.5, 4.8, 'c');
  _line(g, 17, 13, 20.5, 5.5, 3.2, 'c');
  g.ell(21.5, 4.2, 3, 2, 'c');
  g.ell(23.6, 4.8, 1.6, 1.4, 'c');
  g.set(21, 3, 'e');
  g.rect(22, 5, 24, 5, 'e');
  g.rect(7, 17, 9, 21, 'c');
  g.rect(14, 17, 16, 21, 'c');
  g.rect(7, 21, 9, 21, 'e');
  g.rect(14, 21, 16, 21, 'e');
  g.ell(12, 16.5, 5, 2, 'f');
  for (final (sx, sy) in [(9.0, 12.5), (13.0, 11.5), (15.5, 14.0)]) {
    g.ell(sx, sy, 1, 0.9, 'd');
  }
}

void _rocket(Grid g, _Rng r, int v) {
  for (final (sx, sy) in [(3, 3), (21, 5), (5, 14), (22, 13), (18, 1)]) {
    g.set(sx, sy, 'f');
  }
  g.poly([(9.2, 12), (4.5, 19.5), (9.2, 18)], 'd');
  g.poly([(16.8, 12), (21.5, 19.5), (16.8, 18)], 'd');
  g.ell(13, 11, 4.4, 9.6, 'c');
  g.rect(9, 11, 16, 18, 'c');
  g.recolor('c', 'd', (x, y) => y <= 4);
  g.rect(9, 14, 16, 14, 'd');
  g.ell(13, 9, 2.6, 2.6, 'e');
  g.ell(13, 9, 1.7, 1.7, 'f');
  g.set(12, 8, 'a');
  g.rect(11, 19, 14, 19, 'e');
  g.poly([(10.5, 19.6), (15.5, 19.6), (13, 23.5)], 'd');
  g.poly([(11.8, 19.6), (14.2, 19.6), (13, 22)], 'f');
  g.rect(12, 15, 13, 17, 'd');
}

void _rings(Grid g, _Rng r, int v) {
  g.rect(12, 2, 13, 19, 'f');
  g.ell(13, 2.6, 2.2, 2.2, 'c');
  g.set(12, 2, 'f');
  g.ell(13, 20.2, 10, 1.6, 'e');
  g.rect(3, 20, 22, 21, 'e');
  final cols = ['c', 'd', 'c', 'd', 'c'];
  for (var k = 0; k < 5; k++) {
    final yc = 17.6 - k * 3.1;
    final w = 9.4 - k * 1.45;
    g.ell(13, yc, w, 1.9, cols[k]);
    g.set((13 - w * 0.55).floor(), yc.floor() - 1, 'f');
  }
}

void _abacus(Grid g, _Rng r, int v) {
  g.rect(3, 2, 22, 3, 'c');
  g.rect(3, 19, 22, 20, 'c');
  g.rect(3, 2, 4, 20, 'c');
  g.rect(21, 2, 22, 20, 'c');
  g.rect(3, 21, 5, 21, 'e');
  g.rect(20, 21, 22, 21, 'e');
  const rows = [5, 9, 13, 17];
  for (var i = 0; i < rows.length; i++) {
    final y = rows[i];
    g.rect(5, y, 20, y, 'e');
    final left = 1 + (r() * 4).floor();
    final ch = i.isEven ? 'd' : 'f';
    for (var k = 0; k < 5; k++) {
      final bx = k < left ? 5 + k * 3 : 19 - (4 - k) * 3;
      g.rect(bx, y - 1, bx + 1, y + 1, ch);
    }
  }
}

void _pinwheel(Grid g, _Rng r, int v) {
  _line(g, 13, 10, 13, 21.5, 1.4, 'e');
  const cx = 13.0, cy = 9.5;
  for (var k = 0; k < 4; k++) {
    final a = k * math.pi / 2 - math.pi / 4;
    (double, double) p(double ang, double rad) =>
        (cx + math.cos(ang) * rad, cy + math.sin(ang) * rad);
    final tip = p(a, 9.2);
    final side = p(a + math.pi / 4, 6.5);
    final back = p(a - math.pi / 2 + 0.25, 1.5);
    g.poly([(cx, cy), tip, side], k.isEven ? 'c' : 'd');
    g.poly([(cx, cy), back, tip], 'f');
  }
  g.ell(cx, cy, 1.3, 1.3, 'e');
  g.set(12, 8, 'f');
}

void _musicBox(Grid g, _Rng r, int v) {
  g.rect(2, 2, 19, 11, 'c');
  g.rect(4, 4, 17, 10, 'd');
  g.rect(2, 12, 19, 21, 'c');
  g.rect(2, 12, 19, 12, 'e');
  g.rect(4, 14, 17, 19, 'd');
  g.ell(10.5, 17, 1.6, 1.6, 'f');
  g.rect(10, 17, 10, 18, 'e');
  g.rect(20, 16, 21, 16, 'e');
  g.rect(21, 15, 21, 18, 'e');
  // 발레리나
  _line(g, 11, 6.5, 13.5, 3.5, 0.8, 'f');
  _line(g, 10, 6.5, 7.5, 3.5, 0.8, 'f');
  g.ell(10.5, 3.6, 1.4, 1.4, 'e');
  g.ell(10.5, 4.4, 1.1, 1, 'f');
  g.rect(10, 6, 11, 8, 'f');
  g.ell(10.5, 8.6, 3.8, 1.1, 'f');
  g.rect(10, 9, 10, 11, 'f');
  g.rect(11, 9, 11, 10, 'f');
  g.ell(10.5, 11.4, 2.4, 0.7, 'e');
  // 음표
  for (final (nx, ny) in [(22.0, 6.0), (24.0, 10.5)]) {
    g.ell(nx, ny, 1.1, 0.9, 'e');
    g.rect(nx.floor(), ny.floor() - 3, nx.floor(), ny.floor(), 'e');
    g.set(nx.floor() + 1, ny.floor() - 3, 'e');
  }
}

void _rolyPoly(Grid g, _Rng r, int v) {
  g.ell(13, 15.2, 8.6, 6.3, 'c');
  g.ell(13, 6.8, 5.6, 5, 'c');
  g.ell(13, 7.6, 4.2, 3.8, 'f');
  g.rect(9, 3, 16, 4, 'e');
  g.ell(13, 3.6, 3.2, 1.6, 'e');
  g.set(11, 7, 'e');
  g.set(14, 7, 'e');
  g.set(10, 9, 'c');
  g.set(15, 9, 'c');
  g.rect(12, 9, 13, 9, 'e');
  g.ell(13, 16, 4.2, 3.8, 'd');
  g.ell(13, 16, 2.2, 2.0, 'f');
  _line(g, 6.6, 12.5, 9, 16.5, 1, 'd');
  _line(g, 19.4, 12.5, 17, 16.5, 1, 'd');
  g.ell(7.5, 12, 1, 0.7, 'f');
}

void _marbles(Grid g, _Rng r, int v) {
  void marble(double x, double y, double rad, String body, String eye) {
    g.ell(x, y, rad, rad, 'e');
    g.ell(x, y, rad - 0.8, rad - 0.8, body);
    final w = rad * 0.32;
    g.poly([
      (x - rad * 0.55, y + rad * 0.45),
      (x - w, y - w * 0.2),
      (x + rad * 0.55, y - rad * 0.45),
      (x + w, y + w * 0.2),
    ], eye);
    g.ell(x - rad * 0.4, y - rad * 0.45, rad * 0.2 + 0.3, rad * 0.2 + 0.3, 'f');
  }

  marble(13, 11.5, 7.2, 'c', 'd');
  marble(5.2, 18.5, 3.4, 'd', 'c');
  marble(21, 18.6, 3.3, 'f', 'c');
  marble(21.2, 4.6, 2.6, 'd', 'f');
  marble(12.8, 20.4, 1.7, 'f', 'd');
  marble(4.2, 6.8, 2.0, 'c', 'f');
}

void _piggy(Grid g, _Rng r, int v) {
  _ring(g, 3.6, 12, 1.4, 0.8, 'e');
  g.rect(6, 17, 9, 21, 'c');
  g.rect(15, 17, 18, 21, 'c');
  g.ell(12.5, 13, 9, 6.6, 'c');
  g.poly([(15, 8), (17.5, 3.5), (19.5, 8.8)], 'c');
  g.poly([(16.3, 7.8), (17.5, 5.4), (18.6, 8.3)], 'f');
  g.ell(21.6, 13.4, 2.2, 2.6, 'f');
  g.set(21, 13, 'e');
  g.set(22, 13, 'e');
  g.ell(17.5, 11, 0.9, 0.9, 'e');
  g.rect(9, 7, 13, 7, 'e');
  g.ell(11, 3.6, 2.4, 2.4, 'd');
  g.ell(11, 3.6, 1.2, 1.2, 'e');
  g.ell(11, 3.6, 0.6, 0.6, 'd');
  g.ell(8, 10.5, 1.5, 1, 'f');
  g.rect(6, 21, 9, 21, 'e');
  g.rect(15, 21, 18, 21, 'e');
}

void _snowGlobe(Grid g, _Rng r, int v) {
  g.poly([(5, 17), (21, 17), (23, 21.5), (3, 21.5)], 'c');
  g.rect(4, 19, 21, 19, 'e');
  g.ell(13, 10, 9, 9, 'e');
  g.ell(13, 10, 8, 8, 'd');
  g.each(
    (x, y) =>
        math.pow(x - 13, 2) + math.pow(y - 10, 2) <= 64 &&
        y > 14.5 + math.sin(x * 0.6) * 0.6,
    'f',
  );
  g.poly([(13, 4.5), (9, 10.5), (17, 10.5)], 'e');
  g.poly([(13, 7.5), (8, 14.8), (18, 14.8)], 'e');
  g.rect(12, 15, 13, 16, 'e');
  for (var k = 0; k < 14; k++) {
    final x = (5 + r() * 16).floor(), y = (3 + r() * 11).floor();
    if (g.at(x, y) == 'd') {
      g.set(x, y, 'f');
    }
  }
  g.rect(8, 4, 8, 6, 'f');
  g.set(7, 7, 'f');
}

void _dollhouse(Grid g, _Rng r, int v) {
  g.rect(18, 1, 20, 6, 'e');
  g.poly([(1, 10.5), (13, 1), (25, 10.5)], 'd');
  g.ell(13, 7, 1.8, 1.8, 'f');
  g.rect(12, 7, 13, 7, 'e');
  g.rect(12, 6, 13, 8, 'e');
  g.ell(13, 7, 1.8, 1.8, 'f');
  g.rect(3, 10, 22, 21, 'c');
  g.rect(5, 11, 12, 15, 'f');
  g.rect(14, 11, 20, 15, 'f');
  g.rect(5, 17, 12, 21, 'f');
  g.rect(14, 17, 20, 21, 'e');
  // 침대·탁자·램프·계단
  g.rect(6, 14, 10, 15, 'd');
  g.rect(6, 13, 7, 13, 'e');
  g.rect(15, 14, 19, 14, 'e');
  g.rect(15, 15, 15, 15, 'e');
  g.rect(19, 15, 19, 15, 'e');
  g.rect(17, 12, 17, 13, 'd');
  for (var k = 0; k < 4; k++) {
    g.rect(6 + k * 2, 21 - k, 7 + k * 2, 21, 'd');
  }
  g.rect(15, 18, 16, 19, 'f');
  g.rect(18, 18, 19, 19, 'f');
  g.ell(16.5, 20.5, 0.4, 0.4, 'd');
  g.rect(14, 20, 14, 20, 'd');
}

void _bucket(Grid g, _Rng r, int v) {
  g.each((x, y) {
    final d = math.sqrt(math.pow(x - 10, 2) + math.pow(y - 9, 2));
    return (d - 6.8).abs() < 0.5 && y < 9;
  }, 'e');
  g.poly([(3.5, 9.5), (16.5, 9.5), (14.8, 21.5), (5.2, 21.5)], 'c');
  g.rect(3, 8, 16, 9, 'd');
  g.rect(4, 13, 16, 13, 'f');
  g.rect(5, 17, 15, 17, 'f');
  g.ell(10, 15, 1.8, 1.6, 'd');
  _line(g, 22, 2, 20.5, 14, 1.3, 'e');
  g.rect(20, 1, 24, 2, 'd');
  g.poly([
    (17.8, 13.6),
    (23, 14.4),
    (22, 19.2),
    (19.6, 21.4),
    (17.6, 18.6),
  ], 'd');
  g.rect(0, 21, 25, 21, 'b');
  g.ell(8, 21.8, 9, 1.2, 'b');
  for (final (sx, sy) in [(20.0, 23.5), (2.0, 24.0)]) {
    for (var k = 0; k < 5; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / 5;
      _line(
        g,
        sx,
        sy,
        sx + math.cos(a) * 1.6,
        sy + math.sin(a) * 1.6,
        0.8,
        'c',
      );
    }
  }
}

void _rattle(Grid g, _Rng r, int v) {
  _line(g, 12, 12, 19.5, 19.5, 2.4, 'd');
  g.ell(20, 20, 2.2, 2.2, 'c');
  g.ell(20, 20, 0.9, 0.9, 'f');
  g.ell(12.2, 12.2, 2.4, 2.4, 'd');
  g.ell(10, 9, 6.6, 6.6, 'c');
  _ring(g, 10, 9, 4.4, 1, 'f');
  g.ell(10, 9, 2, 2, 'd');
  for (var k = 0; k < 8; k++) {
    final a = k * math.pi / 4;
    g.set(
      (10 + math.cos(a) * 5.7).floor(),
      (9 + math.sin(a) * 5.7).floor(),
      'f',
    );
  }
  g.ell(7.2, 5.6, 1, 0.8, 'f');
  for (final (x0, y0, x1, y1) in [
    (19.0, 3.0, 21.5, 1.5),
    (20.0, 6.5, 23.0, 6.0),
    (1.5, 16.5, 3.5, 18.5),
  ]) {
    _line(g, x0, y0, x1, y1, 0.8, 'e');
  }
}

void _phone(Grid g, _Rng r, int v) {
  g.ell(6, 21, 1.8, 1.8, 'e');
  g.ell(20, 21, 1.8, 1.8, 'e');
  g.poly([(2.5, 20.5), (23.5, 20.5), (20.5, 9.5), (5.5, 9.5)], 'c');
  g.ell(13, 9.8, 7.5, 1.6, 'c');
  g.ell(13, 15, 5.2, 5.2, 'f');
  for (var k = 0; k < 8; k++) {
    final a = -math.pi / 2 + 0.4 + k * math.pi / 5;
    g.ell(13 + math.cos(a) * 3.4, 15 + math.sin(a) * 3.4, 0.7, 0.7, 'e');
  }
  g.ell(13, 15, 1.4, 1.4, 'd');
  _line(g, 3.5, 7, 2, 16, 0.8, 'e');
  g.rect(5, 6, 21, 7, 'd');
  g.ell(5, 6.2, 2.8, 2.4, 'd');
  g.ell(21, 6.2, 2.8, 2.4, 'd');
  g.ell(5, 7.2, 1.2, 0.8, 'e');
  g.ell(21, 7.2, 1.2, 0.8, 'e');
  g.rect(8, 5, 18, 5, 'f');
  _line(g, 2.2, 16, 4, 18, 0.8, 'e');
}

void _bricks(Grid g, _Rng r, int v) {
  void brick(int x0, int x1, int y0, int y1, String ch) {
    for (var sx = x0 + 1; sx + 1 <= x1 - 1; sx += 4) {
      g.rect(sx, y0 - 1, sx + 1, y0 - 1, ch);
    }
    g.rect(x0, y0, x1, y1, ch);
    g.rect(x0, y1, x1, y1, 'e');
    g.rect(x1, y0, x1, y1, 'e');
    g.set(x0 + 1, y0 + 1, 'f');
  }

  brick(1, 12, 16, 21, 'c');
  brick(13, 24, 16, 21, 'd');
  brick(5, 20, 10, 15, 'd');
  brick(9, 16, 4, 9, 'c');
}

void _hobbyHorse(Grid g, _Rng r, int v) {
  _line(g, 14, 12, 5.5, 20, 1.5, 'b');
  _line(g, 14, 12, 5.5, 20, 0.6, 'e');
  g.ell(5, 20.2, 2, 2, 'e');
  g.ell(5, 20.2, 0.8, 0.8, 'f');
  g.poly([
    (10.5, 15.5),
    (11, 6),
    (13, 3),
    (16.5, 3),
    (21.8, 7.2),
    (22, 9.8),
    (19.8, 10.6),
    (16.5, 9.2),
    (16, 15.5),
  ], 'c');
  g.poly([(13.2, 3.6), (13.6, 0.4), (15.2, 3)], 'c');
  _line(g, 12.2, 3.8, 9.8, 14, 2.0, 'd');
  g.ell(16.4, 5.4, 0.9, 0.9, 'e');
  g.set(21, 8, 'e');
  _line(g, 17.5, 4, 17.5, 9.6, 0.8, 'f');
  _line(g, 17.5, 7, 21.5, 7.6, 0.8, 'f');
  g.rect(10, 15, 16, 16, 'd');
}

void _tractor(Grid g, _Rng r, int v) {
  g.rect(5, 2, 13, 3, 'c');
  g.rect(5, 3, 5, 10, 'c');
  g.rect(12, 3, 13, 10, 'c');
  g.rect(6, 4, 11, 9, 'f');
  g.rect(18, 5, 18, 10, 'e');
  g.rect(17, 4, 19, 4, 'e');
  g.rect(4, 10, 23, 15, 'c');
  g.rect(22, 11, 23, 14, 'e');
  g.set(23, 12, 'd');
  g.rect(14, 12, 20, 12, 'd');
  g.each(
    (x, y) => math.pow(x - 8, 2) + math.pow(y - 16, 2) <= 36 && y < 15,
    'c',
  );
  g.ell(8, 16.2, 5.4, 5.4, 'e');
  g.ell(8, 16.2, 2.6, 2.6, 'd');
  g.ell(8, 16.2, 1, 1, 'e');
  g.ell(19.5, 18.4, 3.2, 3.2, 'e');
  g.ell(19.5, 18.4, 1.4, 1.4, 'd');
  for (var k = 0; k < 10; k++) {
    final a = k * math.pi / 5;
    g.set(
      (8 + math.cos(a) * 5.6).floor(),
      (16.2 + math.sin(a) * 5.6).floor(),
      'e',
    );
  }
}

void _bubbles(Grid g, _Rng r, int v) {
  g.rect(3, 12, 9, 21, 'c');
  g.rect(5, 10, 7, 11, 'c');
  g.rect(4, 9, 8, 9, 'e');
  g.rect(4, 15, 8, 18, 'f');
  _ring(g, 6.5, 16.5, 1, 0.7, 'd');
  _line(g, 19.5, 21, 14.6, 11.5, 1.3, 'd');
  _ring(g, 13.2, 8.6, 2.6, 1.1, 'd');
  for (final (bx, by, br) in [
    (19.5, 5.0, 3.6),
    (7.5, 4.0, 2.3),
    (22.5, 13.0, 2.0),
    (13.5, 1.6, 1.2),
  ]) {
    _ring(g, bx, by, br, 0.9, 'f');
    g.set((bx - br * 0.4).floor(), (by - br * 0.4).floor(), 'f');
  }
}

void _fireTruck(Grid g, _Rng r, int v) {
  g.rect(16, 5, 23, 11, 'c');
  g.rect(19, 4, 20, 4, 'd');
  g.poly([(18, 6.5), (22.5, 6.5), (22.5, 10.5), (18, 10.5)], 'f');
  g.rect(1, 11, 24, 17, 'c');
  g.rect(1, 6, 14, 6, 'f');
  g.rect(1, 9, 14, 9, 'f');
  for (var x = 2; x <= 14; x += 3) {
    g.rect(x, 7, x, 8, 'f');
  }
  g.rect(13, 10, 14, 10, 'e');
  g.rect(3, 10, 4, 10, 'e');
  g.rect(2, 13, 13, 13, 'd');
  g.ell(9, 15, 1.8, 1.8, 'e');
  g.ell(9, 15, 0.8, 0.8, 'f');
  g.rect(16, 12, 16, 16, 'e');
  g.rect(24, 13, 25, 14, 'd');
  g.rect(24, 16, 25, 17, 'e');
  g.ell(6, 18, 3.3, 3.3, 'e');
  g.ell(19.5, 18, 3.3, 3.3, 'e');
  g.ell(6, 18, 1.4, 1.4, 'f');
  g.ell(19.5, 18, 1.4, 1.4, 'f');
}

void _paperBoat(Grid g, _Rng r, int v) {
  g.poly([(7.5, 13.5), (13, 2), (18.5, 13.5)], 'f');
  g.poly([(13, 2), (18.5, 13.5), (13, 13.5)], 'c');
  g.poly([(1.5, 12.5), (24.5, 12.5), (19.5, 20.5), (6.5, 20.5)], 'c');
  g.poly([(1.5, 12.5), (13, 12.5), (13, 20.5), (6.5, 20.5)], 'f');
  _line(g, 13, 2.5, 13, 20, 0.7, 'e');
  _line(g, 2, 12.6, 24, 12.6, 0.7, 'e');
  g.rect(0, 21, 25, 21, 'b');
  g.recolor(
    'b',
    'a',
    (x, y) => (y == 22 && (x + 1) % 7 < 3) || (y == 24 && (x + 4) % 7 < 3),
  );
  g.recolor('a', 'b', (x, y) => y == 20 && (x < 6 || x > 20));
  g.ell(3, 5, 0.8, 1.2, 'b');
  g.ell(22, 8, 0.8, 1.2, 'b');
}

void _puppet(Grid g, _Rng r, int v) {
  g.rect(4, 1, 21, 2, 'b');
  g.rect(12, 0, 13, 4, 'b');
  for (final (x0, y0, x1, y1) in [
    (4.5, 2.5, 5.5, 12.0),
    (20.5, 2.5, 20.5, 12.0),
    (12.5, 4.0, 12.5, 5.0),
    (8.0, 2.5, 10.0, 18.0),
    (17.0, 2.5, 16.0, 18.0),
  ]) {
    _line(g, x0, y0, x1, y1, 0.6, 'e');
  }
  g.poly([(10, 6.5), (16, 6.5), (13, 2.5)], 'c');
  g.ell(13, 2.8, 0.9, 0.9, 'd');
  g.ell(13, 8.4, 3, 2.6, 'f');
  g.set(11, 8, 'e');
  g.set(14, 8, 'e');
  g.rect(12, 10, 13, 10, 'c');
  _line(g, 10.5, 12.5, 5.5, 12.5, 1.4, 'c');
  _line(g, 15.5, 12.5, 20.5, 12.5, 1.4, 'c');
  g.ell(5.2, 12.5, 1, 1, 'f');
  g.ell(20.8, 12.5, 1, 1, 'f');
  g.rect(10, 11, 15, 16, 'c');
  g.rect(10, 11, 15, 11, 'd');
  g.set(12, 13, 'd');
  g.set(13, 13, 'd');
  g.set(12, 15, 'd');
  g.set(13, 15, 'd');
  g.rect(10, 17, 12, 19, 'd');
  g.rect(13, 17, 15, 19, 'd');
  g.rect(12, 18, 13, 19, 'a');
  g.rect(9, 20, 11, 20, 'e');
  g.rect(14, 20, 16, 20, 'e');
}

void _castle(Grid g, _Rng r, int v) {
  g.rect(13, 1, 13, 8, 'e');
  g.poly([(13.5, 1), (17, 2.3), (13.5, 3.6)], 'd');
  g.rect(7, 10, 18, 21, 'c');
  for (var x = 7; x <= 18; x += 2) {
    g.rect(x, 8, x, 9, 'c');
  }
  for (final tx in [2, 18]) {
    g.rect(tx, 7, tx + 5, 21, 'c');
    g.poly([(tx - 1.0, 7.5), (tx + 3.0, 0.5), (tx + 7.0, 7.5)], 'd');
    g.rect(tx + 2, 10, tx + 3, 12, 'e');
    g.rect(tx + 2, 15, tx + 3, 16, 'e');
  }
  g.rect(11, 16, 14, 21, 'e');
  g.ell(13, 16, 2, 2, 'e');
  for (var x = 11; x <= 14; x++) {
    if (x.isEven) {
      g.rect(x, 15, x, 21, 'b');
    }
  }
  g.rect(9, 12, 10, 13, 'e');
  g.rect(15, 12, 16, 13, 'e');
  for (final (bx, by) in [
    (8, 17),
    (16, 18),
    (3, 19),
    (21, 13),
    (4, 14),
    (9, 15),
  ]) {
    g.rect(bx, by, bx + 1, by, 'f');
  }
}

// ───────── 목록 ─────────

class _Toy {
  const _Toy(this.id, this.ko, this.en, this.draw, [this.tweak = const {}]);
  final String id, ko, en;
  final void Function(Grid g, _Rng r, int v) draw;

  /// 팔레트 덮어쓰기. '~light' 는 주색을 밝게 섞은 색
  final Map<String, String> tweak;
}

const _skin = '#F6C9A4';

const _toys = [
  _Toy('bear', '곰인형', 'Teddy Bear', _bear),
  _Toy('robot', '태엽 로봇', 'Wind-up Robot', _robot),
  _Toy('rockinghorse', '흔들목마', 'Rocking Horse', _rockingHorse),
  _Toy('top', '팽이', 'Spinning Top', _top),
  _Toy('yoyo', '요요', 'Yo-yo', _yoyo),
  _Toy('duck', '고무 오리', 'Rubber Duck', _duck, {'d': '#F28C28'}),
  _Toy('train', '장난감 기차', 'Toy Train', _train),
  _Toy('blocks', '쌓기 블록', 'Stacking Blocks', _blocks),
  _Toy('kite', '가오리연', 'Diamond Kite', _kite),
  _Toy('beachball', '비치볼', 'Beach Ball', _beachBall),
  _Toy('ragdoll', '헝겊 인형', 'Rag Doll', _ragDoll, {'f': _skin, 'd': '#C0522B'}),
  _Toy('car', '장난감 자동차', 'Toy Car', _car),
  _Toy('drum', '장난감 북', 'Toy Drum', _drum),
  _Toy('jackbox', '깜짝 상자', 'Jack-in-the-Box', _jackBox),
  _Toy('cube', '큐브 퍼즐', 'Puzzle Cube', _cube),
  _Toy('soldier', '장난감 병정', 'Toy Soldier', _soldier, {'f': _skin}),
  _Toy('plane', '장난감 비행기', 'Toy Plane', _plane),
  _Toy('sailboat', '장난감 돛단배', 'Toy Sailboat', _sailboat, {'b': '#5FA8D8'}),
  _Toy('dino', '장난감 공룡', 'Toy Dinosaur', _dino),
  _Toy('rocket', '장난감 로켓', 'Toy Rocket', _rocket),
  _Toy('rings', '링 쌓기', 'Ring Stacker', _rings),
  _Toy('abacus', '주판', 'Abacus', _abacus),
  _Toy('pinwheel', '바람개비', 'Pinwheel', _pinwheel),
  _Toy('musicbox', '오르골', 'Music Box', _musicBox),
  _Toy('rolypoly', '오뚝이', 'Roly-poly Doll', _rolyPoly, {'f': _skin}),
  _Toy('marbles', '유리구슬', 'Glass Marbles', _marbles),
  _Toy('piggybank', '돼지 저금통', 'Piggy Bank', _piggy, {
    'd': '#F5B301',
    'f': '~light',
  }),
  _Toy('snowglobe', '스노볼', 'Snow Globe', _snowGlobe, {'d': '#A9DCF5'}),
  _Toy('dollhouse', '인형의 집', 'Dollhouse', _dollhouse),
  _Toy('bucket', '모래 양동이', 'Sand Bucket', _bucket, {'b': '#E9C987'}),
  _Toy('rattle', '딸랑이', 'Baby Rattle', _rattle),
  _Toy('phone', '장난감 전화기', 'Toy Telephone', _phone),
  _Toy('bricks', '조립 블록', 'Building Bricks', _bricks),
  _Toy('hobbyhorse', '막대 말', 'Hobby Horse', _hobbyHorse),
  _Toy('tractor', '장난감 트랙터', 'Toy Tractor', _tractor),
  _Toy('bubbles', '비눗방울 놀이', 'Bubble Wand', _bubbles),
  _Toy('firetruck', '장난감 소방차', 'Toy Fire Truck', _fireTruck),
  _Toy('paperboat', '종이배', 'Paper Boat', _paperBoat, {
    'f': '~light',
    'b': '#6FB3E0',
  }),
  _Toy('puppet', '꼭두각시 인형', 'Marionette', _puppet, {'f': _skin}),
  _Toy('castle', '장난감 성', 'Toy Castle', _castle),
];

class _Scheme {
  const _Scheme(this.ko, this.en, this.pal);
  final String ko, en;
  final Map<String, String> pal;
}

const _schemes = [
  _Scheme('빨간', 'Red', {
    'a': '#CFE8F7',
    'b': '#D9A066',
    'c': '#E5484D',
    'd': '#F5B301',
    'e': '#3B2A2A',
    'f': '#FFFFFF',
  }),
  _Scheme('파란', 'Blue', {
    'a': '#FDE7C8',
    'b': '#B9875A',
    'c': '#3B7DD8',
    'd': '#F28C28',
    'e': '#1F2A44',
    'f': '#FFFFFF',
  }),
  _Scheme('노란', 'Yellow', {
    'a': '#DCD3F7',
    'b': '#A47148',
    'c': '#F5C518',
    'd': '#2BA59B',
    'e': '#3A2E1F',
    'f': '#FFFFFF',
  }),
  _Scheme('초록', 'Green', {
    'a': '#FBD9E4',
    'b': '#C08457',
    'c': '#3FAE5A',
    'd': '#7B61D9',
    'e': '#233127',
    'f': '#FFFFFF',
  }),
];

/// 장난감 160장 (40가지 × 색 4가지)
List<ArtSource> toyArts() {
  final out = <ArtSource>[];
  for (var k = 0; k < _toys.length; k++) {
    final t = _toys[k];
    for (var v = 0; v < _schemes.length; v++) {
      final s = _schemes[v];
      final g = Grid(26, 26)..rect(0, 0, 25, 25, 'a');
      g.rect(0, 22, 25, 25, 'b');
      t.draw(g, mulberry32(9100 + k * 10 + v), v);
      _round(g, 2.5);
      final pal = {...s.pal};
      t.tweak.forEach((key, val) {
        pal[key] = val == '~light' ? _mix(s.pal['c']!, '#FFFFFF', 0.55) : val;
      });
      out.add(
        makeArt(
          't_${t.id}_${v + 1}',
          '${s.ko} ${t.ko}',
          '${s.en} ${t.en}',
          pal,
          g,
        ),
      );
    }
  }
  return out;
}
