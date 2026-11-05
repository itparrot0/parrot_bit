// 칸 애니메이션 스프라이트 (씨앗 · 발아 · 스킨별 개화).
//
// 파일 규격 (assets/anim/, 자세한 설명은 docs/anim/README.md):
//   seed.png, sprout.png, bloom_<스킨 id>.png — tint 레이어 (회색조, 게임이 칸 색을 곱한다)
//   같은 이름 + _light.png                      — light 레이어 (선택, 색 없이 그대로 위에 얹는다)
//   한 프레임 = 정사각형 한 칸, 가로로 이어 붙인다 → 프레임 수 = 가로 / 세로
//   anim.json — 시트별 프레임 길이 {"sprout": {"frameMs": 32}, ...} (없으면 32ms)
// 마지막 프레임 = 그 상태의 정지 모습. 파일이 없으면 cell_sprites_gen.dart 의 코드 그림으로 만든다.
// 불러오기 전에는 게임이 예전 코드 그리기(shapes.dart)로 그린다.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cell_sprites_gen.dart';

const double defaultFrameMs = 32;

class SpriteSheet {
  SpriteSheet(this.tint, this.light, this.frameMs)
    : frames = (tint.width / tint.height).round().clamp(1, 1 << 16),
      size = tint.height.toDouble();
  final ui.Image tint;
  final ui.Image? light;
  final double frameMs;
  final int frames;

  /// 한 프레임 한 변 (px)
  final double size;

  double get durationMs => frames * frameMs;

  /// 시작 뒤 [elapsedMs] 일 때 보일 프레임. 끝나면 마지막 프레임에 머문다
  int frameAt(double elapsedMs) => spriteFrameAt(elapsedMs, frames, frameMs);
}

int spriteFrameAt(double elapsedMs, int frames, double frameMs) {
  if (frames <= 1 || elapsedMs < 0) return 0;
  if (frameMs <= 0) return frames - 1;
  final f = (elapsedMs / frameMs).floor();
  return f >= frames ? frames - 1 : f;
}

/// anim.json 에서 시트의 프레임 길이를 읽는다 (bloom_<스킨> 이 없으면 "bloom" 값, 그것도 없으면 기본값)
double frameMsFor(Map<String, dynamic> manifest, String sheet) {
  num? read(String k) {
    final v = manifest[k];
    return v is Map ? v['frameMs'] as num? : null;
  }

  return (read(sheet) ?? (sheet.startsWith('bloom_') ? read('bloom') : null))
          ?.toDouble() ??
      defaultFrameMs;
}

class CellSprites {
  CellSprites({this.bundle});
  static final CellSprites instance = CellSprites();

  /// 테스트용 (없으면 rootBundle)
  final AssetBundle? bundle;
  AssetBundle get _b => bundle ?? rootBundle;

  final Map<String, SpriteSheet> _sheets = {};
  final Map<String, Future<void>> _loading = {};
  Map<String, dynamic>? _manifest;

  /// 번들에 든 파일 목록 (없는 파일은 요청하지 않는다 — 웹에서 404 방지). 못 읽으면 null = 일단 요청
  Set<String>? _assets;
  bool _assetsRead = false;

  SpriteSheet? get seed => _sheets['seed'];
  SpriteSheet? get sprout => _sheets['sprout'];
  SpriteSheet? bloomOf(String skinId) => _sheets['bloom_$skinId'];

  /// 이 스킨으로 칸을 그릴 시트가 다 있나
  bool ready(String skinId) =>
      seed != null && sprout != null && bloomOf(skinId) != null;

  /// 씨앗·발아·이 스킨의 개화 시트를 (아직이면) 불러온다
  Future<void> ensure(String skinId) =>
      Future.wait([_get('seed'), _get('sprout'), _get('bloom_$skinId')]);

  Future<void> _get(String sheet) =>
      _loading.putIfAbsent(sheet, () => _load(sheet));

  Future<void> _load(String sheet) async {
    _manifest ??= await _readManifest();
    if (!_assetsRead) {
      _assetsRead = true;
      try {
        _assets = (await AssetManifest.loadFromAssetBundle(
          _b,
        )).listAssets().toSet();
      } catch (_) {}
    }
    final ms = frameMsFor(_manifest!, sheet);
    var tint = await _png('assets/anim/$sheet.png');
    ui.Image? light;
    if (tint != null) {
      light = await _png('assets/anim/${sheet}_light.png');
    } else {
      final n = defaultFrames(sheet);
      tint = await renderSheet(sheet, n, light: false);
      light = await renderSheet(sheet, n, light: true);
    }
    _sheets[sheet] = SpriteSheet(tint, light, ms);
  }

  Future<Map<String, dynamic>> _readManifest() async {
    try {
      return jsonDecode(await _b.loadString('assets/anim/anim.json'))
          as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  Future<ui.Image?> _png(String path) async {
    if (_assets != null && !_assets!.contains(path)) return null;
    try {
      final data = await _b.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (e) {
      if (kDebugMode && !path.endsWith('_light.png')) {
        debugPrint('cell sprite $path 없음 → 코드 그림 사용');
      }
      return null;
    }
  }
}
