// 설정: 사운드, 진동, 빠른 연출, 언어, 광고 제거(인앱 결제), 개인정보처리방침, 버전.
// 홈에는 시작 버튼만 두므로(2026-11-04) 설정은 게임의 일시정지 메뉴에서 연다.
import 'package:flutter/material.dart';

import '../app.dart';
import '../platform/billing.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  String? _notice;
  bool _privacy = false;
  bool _busy = false;

  Future<void> _buyNoAds(AppServices app) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await app.billing
        .purchase(Products.removeAds)
        .catchError((_) => false);
    if (ok) await app.save.setNoAds(true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = app.t(ok ? 'purchaseDone' : 'purchaseFailed');
    });
    app.changed();
  }

  Future<void> _restore(AppServices app) async {
    if (_busy) return;
    setState(() => _busy = true);
    final owned = await app.billing.restore().catchError((_) => <String>[]);
    final got = owned.contains(Products.removeAds);
    if (got) await app.save.setNoAds(true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (got) _notice = app.t('purchaseDone');
    });
    app.changed();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final s = app.save.data.settings;
    final owned = app.save.data.noAds;
    Widget row(String key, Widget control) => Container(
      height: 150,
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.symmetric(horizontal: 50),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(app.t(key), style: textStyle(46)),
            ),
          ),
          const SizedBox(width: 20),
          control,
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OverlayPanel(
          key: const ValueKey('overlay-settings'),
          w: 980,
          h: 1900,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(50, 60, 50, 50),
            child: Column(
              children: [
                Label(app.t('settings'), size: 64),
                const SizedBox(height: 50),
                row(
                  'sound',
                  ToggleSwitch(
                    key: const ValueKey('toggle-sound'),
                    value: s.sound,
                    onChanged: (v) => app.updateSettings(s.copyWith(sound: v)),
                  ),
                ),
                row(
                  'vibration',
                  ToggleSwitch(
                    key: const ValueKey('toggle-vibration'),
                    value: s.vibration,
                    onChanged: (v) =>
                        app.updateSettings(s.copyWith(vibration: v)),
                  ),
                ),
                row(
                  'language',
                  Segmented(
                    w: 190,
                    options: const [('ko', '한국어'), ('en', 'English')],
                    value: s.lang,
                    onChanged: (v) => app.updateSettings(s.copyWith(lang: v)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PillButton(
                      owned ? app.t('removeAdsOwned') : app.t('removeAds'),
                      key: const ValueKey('btn-remove-ads'),
                      w: 520,
                      h: 140,
                      color: owned ? C.bgDeep : C.accent,
                      textColor: owned ? C.inkSoft : Colors.white,
                      enabled: !owned && !_busy,
                      onClick: app.sfx.click,
                      onTap: () => _buyNoAds(app),
                    ),
                    PillButton(
                      app.t('restorePurchases'),
                      key: const ValueKey('btn-restore'),
                      w: 330,
                      h: 140,
                      size: 38,
                      color: C.bg,
                      textColor: C.ink,
                      enabled: !_busy,
                      onClick: app.sfx.click,
                      onTap: () => _restore(app),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                PillButton(
                  app.t('privacy'),
                  key: const ValueKey('btn-privacy'),
                  w: 880,
                  h: 140,
                  color: C.bg,
                  textColor: C.ink,
                  onClick: app.sfx.click,
                  onTap: () => setState(() => _privacy = true),
                ),
                const SizedBox(height: 24),
                Label(
                  app.t('version', {'v': app.version}),
                  size: 36,
                  color: C.inkSoft,
                  weight: FontWeight.w500,
                ),
                const Spacer(),
                PillButton(
                  app.t('close'),
                  key: const ValueKey('btn-settings-close'),
                  w: 560,
                  onClick: app.sfx.click,
                  onTap: widget.onClose,
                ),
              ],
            ),
          ),
        ),
        if (_privacy)
          OverlayPanel(
            key: const ValueKey('overlay-privacy'),
            w: 980,
            h: 1120,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 70, 60, 50),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        app.t('privacyText'),
                        textAlign: TextAlign.center,
                        style: textStyle(
                          38,
                          weight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                  PillButton(
                    'OK',
                    w: 400,
                    onClick: app.sfx.click,
                    onTap: () => setState(() => _privacy = false),
                  ),
                ],
              ),
            ),
          ),
        if (_notice != null)
          OverlayPanel(
            key: const ValueKey('overlay-notice'),
            w: 820,
            h: 420,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Label(_notice!, size: 46),
                const SizedBox(height: 60),
                PillButton(
                  'OK',
                  key: const ValueKey('btn-notice-ok'),
                  w: 360,
                  onClick: app.sfx.click,
                  onTap: () => setState(() => _notice = null),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
