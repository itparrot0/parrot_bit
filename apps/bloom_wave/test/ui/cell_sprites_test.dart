import 'dart:io';

import 'package:bloom_wave/economy/skins.dart';
import 'package:bloom_wave/ui/cell_sprites.dart';
import 'package:bloom_wave/ui/cell_sprites_gen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 파일이 하나도 없는 번들 (코드 그림으로 대체되는지 확인)
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('없음 $key');
}

void main() {
  test('프레임 고르기: 시작 전 0, 진행 중 경과/프레임 길이, 끝나면 마지막에 머문다', () {
    expect(spriteFrameAt(-5, 8, 32), 0);
    expect(spriteFrameAt(0, 8, 32), 0);
    expect(spriteFrameAt(65, 8, 32), 2);
    expect(spriteFrameAt(1e9, 8, 32), 7);
    expect(spriteFrameAt(100, 1, 32), 0);
    expect(spriteFrameAt(10, 8, 0), 7);
  });

  test('anim.json: 시트 값 → 스킨 개화는 "bloom" 값 → 기본값', () {
    final m = {
      'sprout': {'frameMs': 40},
      'bloom': {'frameMs': 30},
      'bloom_tulip': {'frameMs': 50},
    };
    expect(frameMsFor(m, 'sprout'), 40);
    expect(frameMsFor(m, 'bloom_tulip'), 50);
    expect(frameMsFor(m, 'bloom_daisy'), 30);
    expect(frameMsFor(const {}, 'sprout'), defaultFrameMs);
  });

  test('모든 스킨에 개화 시트가 있고, 프레임이 정사각형으로 이어져 있다', () {
    for (final name in [
      'seed',
      'sprout',
      for (final s in skins) 'bloom_${s.id}',
    ]) {
      final f = File('assets/anim/$name.png');
      expect(f.existsSync(), isTrue, reason: name);
      final b = f.readAsBytesSync();
      // PNG IHDR: 가로·세로 (빅엔디언)
      final w = ByteData.sublistView(b, 16, 20).getUint32(0);
      final h = ByteData.sublistView(b, 20, 24).getUint32(0);
      expect(w % h, 0, reason: '$name: 가로가 세로의 배수가 아니다');
    }
  });

  test('애니메이션 길이가 기본 속도의 틱 예산(360ms) 안에 든다', () {
    final m = {
      'sprout': {'frameMs': defaultFrameMs},
      'bloom': {'frameMs': defaultFrameMs},
    };
    expect(sproutFrames * frameMsFor(m, 'sprout'), lessThanOrEqualTo(360));
    expect(bloomFrames * frameMsFor(m, 'bloom'), lessThanOrEqualTo(360));
  });

  testWidgets('파일이 없으면 코드 그림으로 시트를 만든다', (tester) async {
    final sp = CellSprites(bundle: _EmptyBundle());
    expect(sp.ready('tulip'), isFalse);
    await tester.runAsync(() => sp.ensure('tulip'));
    expect(sp.ready('tulip'), isTrue);
    expect(sp.ready('daisy'), isFalse);
    expect(sp.sprout!.frames, sproutFrames);
    expect(sp.bloomOf('tulip')!.frames, bloomFrames);
    expect(sp.bloomOf('tulip')!.light, isNotNull);
    expect(sp.seed!.frames, 1);
  });

  testWidgets('에셋 PNG 를 읽는다', (tester) async {
    final sp = CellSprites();
    await tester.runAsync(() => sp.ensure('sakura'));
    expect(sp.ready('sakura'), isTrue);
    expect(sp.bloomOf('sakura')!.frames, bloomFrames);
    expect(sp.sprout!.frameMs, defaultFrameMs);
    expect(sp.seed!.light, isNull);
  });
}
