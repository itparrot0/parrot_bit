import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/ui/skin_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('스킨마다 꽃 모양이 상자를 고르게 채운다 (꽃잎 회전이 빠지지 않았다)', () {
    for (final s in skins) {
      final b = skinPath(s.id).getBounds();
      expect(b.width, greaterThan(60), reason: s.id);
      expect(b.height, greaterThan(60), reason: s.id);
      expect(b.center.dx, closeTo(64, 12), reason: s.id);
      // 네 방향 모두에 꽃이 있다 (조각마다 꽃의 일부가 보인다)
      for (final p in const [
        Offset(40, 40),
        Offset(88, 40),
        Offset(40, 88),
        Offset(88, 88),
      ]) {
        final probe = Rect.fromCenter(center: p, width: 30, height: 30);
        var hit = false;
        for (var x = probe.left; x <= probe.right && !hit; x += 3) {
          for (var y = probe.top; y <= probe.bottom && !hit; y += 3) {
            hit = skinPath(s.id).contains(Offset(x, y));
          }
        }
        expect(hit, isTrue, reason: '${s.id} 의 $p 쪽이 비었다');
      }
    }
  });

  test('경로는 한 번만 만들어 재사용한다 (게임 보드 성능)', () {
    for (final s in skins) {
      expect(identical(skinPath(s.id), skinPath(s.id)), isTrue);
    }
  });
}
