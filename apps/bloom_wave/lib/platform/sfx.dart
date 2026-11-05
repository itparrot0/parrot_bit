// 짧은 효과음. 소리 파일 없이 코드로 파형을 만들어(WAV) 재생한다 — TS 버전의 Web Audio 효과음과 같은 음.
// 개화음은 웨이브의 틱마다 반음씩 올라간다.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

abstract class Sfx {
  bool enabled = true;
  void tap();
  void deny();
  void bloom();

  /// 웨이브가 멈추면 개화음 높이를 처음으로
  void resetPitch();
  void clear();
  void fail();
  void click();

  /// 골드 받는 소리
  void coin();
}

/// 테스트·무음용
class SilentSfx extends Sfx {
  final List<String> played = [];
  @override
  void tap() => played.add('tap');
  @override
  void deny() => played.add('deny');
  @override
  void bloom() => played.add('bloom');
  @override
  void resetPitch() {}
  @override
  void clear() => played.add('clear');
  @override
  void fail() => played.add('fail');
  @override
  void click() => played.add('click');
  @override
  void coin() => played.add('coin');
}

enum Wave { sine, triangle, square, sawtooth }

class Note {
  const Note(this.freq, this.dur, this.wave, this.gain, [this.delay = 0]);
  final double freq;
  final double dur;
  final Wave wave;
  final double gain;
  final double delay;
}

/// 음표 여러 개를 섞어 16비트 모노 WAV 로 만든다
Uint8List synthWav(List<Note> notes, {int rate = 22050}) {
  final total = notes.map((n) => n.delay + n.dur + 0.03).reduce(math.max);
  final len = (total * rate).ceil();
  final mix = Float64List(len);
  for (final n in notes) {
    final start = (n.delay * rate).round();
    final count = (n.dur * rate).round();
    final attack = 0.01 * rate;
    for (var i = 0; i < count && start + i < len; i++) {
      final t = i / rate;
      final ph = (n.freq * t) % 1.0;
      final v = switch (n.wave) {
        Wave.sine => math.sin(2 * math.pi * ph),
        Wave.triangle => 1 - 4 * (ph - 0.5).abs(),
        Wave.square => ph < 0.5 ? 1.0 : -1.0,
        Wave.sawtooth => 2 * ph - 1,
      };
      // Web Audio 의 exponentialRamp 와 같은 모양: 0.0001 → gain (10ms) → 0.0001
      final env = i < attack
          ? 0.0001 * math.pow(n.gain / 0.0001, i / attack)
          : n.gain * math.pow(0.0001 / n.gain, (i - attack) / (count - attack));
      mix[start + i] += v * env;
    }
  }
  final data = ByteData(44 + len * 2);
  void str(int o, String s) {
    for (var k = 0; k < s.length; k++) {
      data.setUint8(o + k, s.codeUnitAt(k));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + len * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, len * 2, Endian.little);
  for (var i = 0; i < len; i++) {
    final s = (mix[i] * 32767 * 2.2).clamp(-32768, 32767).round();
    data.setInt16(44 + i * 2, s, Endian.little);
  }
  return data.buffer.asUint8List();
}

double _semi(double base, num s) => base * math.pow(2, s / 12);

class SynthSfx extends Sfx {
  final Map<String, Uint8List> _cache = {};
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  int _step = 0;

  Uint8List _wav(String key, List<Note> Function() make) =>
      _cache.putIfAbsent(key, () => synthWav(make()));

  void _play(String key, List<Note> Function() make) {
    if (!enabled) return;
    try {
      if (_pool.length < 6) {
        _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
      final p = _pool[_next++ % _pool.length];
      p.play(BytesSource(_wav(key, make), mimeType: 'audio/wav'));
    } catch (_) {
      // 소리 실패는 게임에 영향을 주지 않는다
    }
  }

  @override
  void resetPitch() => _step = 0;

  @override
  void bloom() {
    final s = math.min(_step, 24);
    _step++;
    _play('bloom$s', () => [Note(_semi(523.25, s), 0.18, Wave.triangle, 0.09)]);
  }

  @override
  void tap() => _play('tap', () => const [Note(330, 0.08, Wave.sine, 0.08)]);
  @override
  void deny() =>
      _play('deny', () => const [Note(160, 0.12, Wave.square, 0.05)]);
  @override
  void clear() => _play(
    'clear',
    () => [
      for (final (i, s) in const [0, 4, 7, 12].indexed)
        Note(_semi(523.25, s), 0.35, Wave.triangle, 0.1, i * 0.09),
    ],
  );
  @override
  void fail() => _play(
    'fail',
    () => [
      for (final (i, s) in const [0, -3, -7].indexed)
        Note(_semi(220, s), 0.3, Wave.sawtooth, 0.05, i * 0.12),
    ],
  );
  @override
  void click() =>
      _play('click', () => const [Note(660, 0.05, Wave.sine, 0.05)]);
  @override
  void coin() => _play(
    'coin',
    () => const [
      Note(987.77, 0.08, Wave.square, 0.04),
      Note(1318.51, 0.22, Wave.square, 0.04, 0.07),
    ],
  );
}
