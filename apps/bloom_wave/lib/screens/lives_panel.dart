// 햇빛 패널: 지금 개수(해 5개), 다음 회복까지 남은 시간, 가득 채우기(골드 / 광고 하루 1번).
// 홈에서 햇빛 배지를 누르거나 햇빛 없이 시작하려 할 때, 게임에서 햇빛 없이 다시 하려 할 때 뜬다.
import 'package:flutter/material.dart';

import '../app.dart';
import '../economy/lives.dart';
import '../ui/sun.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class LivesPanel extends StatefulWidget {
  const LivesPanel({
    super.key,
    required this.app,
    required this.onClose,
    this.empty = false,
  });
  final AppServices app;
  final VoidCallback onClose;

  /// 햇빛이 없어서 열렸나 (제목이 "햇빛이 없어요")
  final bool empty;

  @override
  State<LivesPanel> createState() => _LivesPanelState();
}

class _LivesPanelState extends State<LivesPanel> {
  bool _busy = false;
  String _msg = '';
  Color _msgColor = C.inkSoft;

  AppServices get app => widget.app;

  void _say(String key, Color color) => setState(() {
    _msg = app.t(key);
    _msgColor = color;
  });

  Future<void> _gold() async {
    if (_busy) return;
    if (app.save.data.gold < refillGoldCost) {
      _say('livesNoGold', C.warn);
      return;
    }
    if (await app.save.refillLivesWithGold(app.clock())) {
      app.sfx.coin();
      app.changed();
      _say('livesFilled', C.accentDark);
    }
  }

  Future<void> _ad() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await app.ads.rewarded();
    if (!mounted) return;
    // 광고를 보는 동안 날짜가 바뀌어도 광고를 시작한 날로 친다
    if (ok && await app.save.refillLivesWithAd(app.clock())) {
      app.changed();
      _say('livesFilled', C.accentDark);
    } else if (!ok) {
      _say('livesAdFailed', C.warn);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => OverlayPanel(
    key: const ValueKey('overlay-lives'),
    w: 900,
    h: 1240,
    child: EverySecond(
      builder: (context) {
        final now = app.clock();
        final lives = app.save.data.lives;
        final left = lives.untilNext(now);
        final adOk = lives.adAvailable(now);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 60),
          child: Column(
            children: [
              Label(
                app.t(
                  widget.empty && lives.count == 0
                      ? 'livesEmptyTitle'
                      : 'lives',
                ),
                size: 60,
              ),
              const SizedBox(height: 40),
              Row(
                key: const ValueKey('lives-suns'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < maxLives; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SunIcon(size: 120, on: i < lives.count),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Label(
                left == null
                    ? app.t('livesFull')
                    : app.t('livesNext', {'t': formatLeft(left)}),
                key: const ValueKey('lives-panel-timer'),
                size: 44,
                color: C.inkSoft,
              ),
              const SizedBox(height: 30),
              Label(
                app.t('livesInfo'),
                size: 32,
                color: C.inkSoft,
                weight: FontWeight.w500,
                height: 1.4,
              ),
              const Spacer(),
              PillButton(
                app.t('livesRefillGold', {'n': refillGoldCost}),
                key: const ValueKey('btn-lives-gold'),
                w: 720,
                h: 130,
                size: 42,
                color: C.gold,
                textColor: C.ink,
                enabled: !lives.full && !_busy,
                leading: const CoinIcon(size: 56),
                onClick: app.sfx.click,
                onTap: _gold,
              ),
              const SizedBox(height: 24),
              PillButton(
                app.t('livesRefillAd'),
                key: const ValueKey('btn-lives-ad'),
                w: 720,
                h: 130,
                size: 42,
                enabled: !lives.full && adOk && !_busy,
                leading: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 56,
                  color: Colors.white,
                ),
                onClick: app.sfx.click,
                onTap: _ad,
              ),
              const SizedBox(height: 14),
              Label(
                app.t(adOk ? 'livesAdLeft' : 'livesAdUsed'),
                key: const ValueKey('lives-ad-note'),
                size: 30,
                color: C.inkSoft,
                weight: FontWeight.w500,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: Label(
                  _msg,
                  key: const ValueKey('lives-msg'),
                  size: 36,
                  color: _msgColor,
                ),
              ),
              const SizedBox(height: 10),
              PillButton(
                app.t('close'),
                key: const ValueKey('btn-lives-close'),
                w: 420,
                color: C.bgDeep,
                textColor: C.ink,
                onClick: app.sfx.click,
                onTap: widget.onClose,
              ),
            ],
          ),
        );
      },
    ),
  );
}
