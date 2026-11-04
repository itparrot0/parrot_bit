// 진동. 설정에서 끌 수 있고, 틱마다 울리면 너무 잦아 90ms 안에는 한 번만 울린다.
import 'package:flutter/services.dart';

class Haptics {
  bool enabled = true;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void light() {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 90) return;
    _last = now;
    HapticFeedback.lightImpact();
  }

  void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void fail() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
