// 꽃 스킨 모양. 스킨마다 128×128 상자 안의 경로(Path) 하나를 처음 한 번만 만들어 두고 재사용한다 —
// 게임 보드는 개화 칸마다 drawPath 한 번만 부르므로 어떤 스킨을 써도 그리는 비용이 같다 (성능 영향 없음).
// 스킨 카드(상점·뽑기)는 같은 경로를 크게 그리고 2×2 퍼즐 조각으로 나눠 보여 준다.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

const double _s = 128;
const Offset _c = Offset(64, 64);

Path _circles(List<(Offset, double)> cs) {
  final p = Path();
  for (final (o, r) in cs) {
    p.addOval(Rect.fromCircle(center: o, radius: r));
  }
  return p;
}

/// 중심에서 거리 d, 각도 a 에 놓인 (가로 w, 세로 h) 꽃잎. 긴 쪽이 바깥을 향한다
Path _petal(double a, double d, double w, double h) {
  final m = Matrix4Lite.rotation(a + math.pi / 2, _c);
  // Path.transform 은 새 경로를 돌려준다 (제자리에서 바뀌지 않음)
  return (Path()..addOval(
        Rect.fromCenter(center: Offset(64, 64 - d), width: w, height: h),
      ))
      .transform(m.storage);
}

Path _union(Iterable<Path> ps) {
  Path? out;
  for (final p in ps) {
    out = out == null ? p : Path.combine(PathOperation.union, out, p);
  }
  return out ?? Path();
}

Path _build(String id) {
  switch (id) {
    case 'daisy':
      return _union([
        for (var i = 0; i < 10; i++) _petal(i * math.pi / 5, 30, 15, 40),
        _circles([(_c, 15)]),
      ]);
    case 'tulip':
      return _union([
        Path()
          ..moveTo(32, 46)
          ..lineTo(36, 22)
          ..lineTo(50, 40)
          ..lineTo(64, 18)
          ..lineTo(78, 40)
          ..lineTo(92, 22)
          ..lineTo(96, 46)
          ..quadraticBezierTo(96, 92, 64, 96)
          ..quadraticBezierTo(32, 92, 32, 46)
          ..close(),
        Path()..addRect(const Rect.fromLTWH(60, 94, 8, 18)),
      ]);
    case 'sakura':
      // 꽃잎 다섯 장, 끝에 작은 홈
      final petals = _union([
        for (var i = 0; i < 5; i++)
          _petal(-math.pi / 2 + i * 2 * math.pi / 5, 26, 34, 46),
      ]);
      final notches = _union([
        for (var i = 0; i < 5; i++)
          _petal(-math.pi / 2 + i * 2 * math.pi / 5, 50, 10, 14),
      ]);
      return Path.combine(PathOperation.difference, petals, notches);
    case 'sunflower':
      final rays = Path();
      for (var i = 0; i < 14; i++) {
        final a = i * 2 * math.pi / 14;
        Offset at(double r, double da) =>
            Offset(64 + math.cos(a + da) * r, 64 + math.sin(a + da) * r);
        rays
          ..moveTo(at(22, -0.2).dx, at(22, -0.2).dy)
          ..lineTo(at(54, 0).dx, at(54, 0).dy)
          ..lineTo(at(22, 0.2).dx, at(22, 0.2).dy)
          ..close();
      }
      return _union([
        rays,
        _circles([(_c, 24)]),
      ]);
    case 'clover':
      // 하트 모양 잎 네 장
      return _union([
        for (var i = 0; i < 4; i++)
          () {
            final a = i * math.pi / 2;
            final heart = Path()
              ..addOval(
                Rect.fromCircle(center: const Offset(55, 36), radius: 13),
              )
              ..addOval(
                Rect.fromCircle(center: const Offset(73, 36), radius: 13),
              )
              ..moveTo(43, 40)
              ..lineTo(64, 64)
              ..lineTo(85, 40)
              ..close();
            return heart.transform(Matrix4Lite.rotation(a, _c).storage);
          }(),
        _circles([(_c, 8)]),
      ]);
    default: // basic: 동그란 꽃잎 다섯 장 + 가운데 (전환 전과 같은 모양)
      return _circles([
        for (var i = 0; i < 5; i++)
          (
            Offset(
              64 + math.cos(-math.pi / 2 + i * 2 * math.pi / 5) * 26,
              64 + math.sin(-math.pi / 2 + i * 2 * math.pi / 5) * 26,
            ),
            22,
          ),
        (_c, 16),
      ]);
  }
}

final Map<String, Path> _cache = {};

/// 스킨의 꽃 경로 (128 상자 좌표). 처음 한 번만 만든다
Path skinPath(String id) => _cache.putIfAbsent(id, () => _build(id));

/// 꽃 하나를 (중심 c, 한 변 size) 에 그린다
void drawSkinGlyph(
  Canvas canvas,
  Offset c,
  double size,
  Color color,
  String skinId,
) {
  canvas.save();
  canvas.translate(c.dx - size / 2, c.dy - size / 2);
  canvas.scale(size / _s);
  canvas.drawPath(skinPath(skinId), Paint()..color = color);
  canvas.restore();
}

/// 2D 회전만 필요한 작은 4×4 행렬 (Path.transform 용)
class Matrix4Lite {
  Matrix4Lite._(this.storage);
  final Float64List storage;

  factory Matrix4Lite.rotation(double a, Offset pivot) {
    final c = math.cos(a), s = math.sin(a);
    final tx = pivot.dx - c * pivot.dx + s * pivot.dy;
    final ty = pivot.dy - s * pivot.dx - c * pivot.dy;
    return Matrix4Lite._(
      Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]),
    );
  }
}
