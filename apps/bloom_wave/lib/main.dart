import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'domain/engine.dart' show Level;
import 'platform/ads.dart';
import 'platform/billing.dart';
import 'platform/haptics.dart';
import 'platform/sfx.dart';
import 'save/save_store.dart';
import 'ui/cell_sprites.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

/// 출시 레벨 팩 (tool/levelgen 이 만든 assets/levels/pack-01.json)
Future<List<Level>> loadPack() async {
  final raw =
      jsonDecode(await rootBundle.loadString('assets/levels/pack-01.json'))
          as List;
  return [for (final j in raw) Level.fromJson(j as Map<String, dynamic>)];
}

bool get _mobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final levels = await loadPack();
  final save = SaveStore(PrefsStore());
  final lang = PlatformDispatcher.instance.locale.languageCode == 'ko'
      ? 'ko'
      : 'en';
  final data = await save.load(lang: lang);
  // 칸 애니메이션 시트는 기다리지 않고 뒤에서 불러 둔다 (준비 전에는 코드 그리기)
  CellSprites.instance.ensure(data.skin.id);
  final navigatorKey = GlobalKey<NavigatorState>();

  final AdProvider provider = _mobile
      ? AdMobProvider()
      : MockAdProvider(() => _showMockAd(navigatorKey));
  await provider.init();
  final sfx = SynthSfx()..enabled = data.settings.sound;
  final haptics = Haptics()..enabled = data.settings.vibration;
  final services = AppServices(
    levels: levels,
    save: save,
    ads: Ads(provider),
    billing: _mobile ? StoreBilling() : DevBilling(),
    sfx: sfx,
    haptics: haptics,
  );
  // 결제 결과 듣기 시작 (지난번에 끝나지 않은 골드 결제도 여기서 지급)
  services.billing.start();
  runApp(BloomWaveApp(services: services, navigatorKey: navigatorKey));
}

/// 웹·데스크톱용 가짜 광고: 화면을 덮고 1초 뒤 닫을 수 있다 (흐름 확인용)
Future<void> _showMockAd(GlobalKey<NavigatorState> nav) async {
  final ctx = nav.currentContext;
  if (ctx == null) return;
  await Navigator.of(ctx).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (context, _, _) => const _MockAd(),
    ),
  );
}

class _MockAd extends StatefulWidget {
  const _MockAd();
  @override
  State<_MockAd> createState() => _MockAdState();
}

class _MockAdState extends State<_MockAd> {
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canClose = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return PopScope(
      canPop: _canClose,
      child: LogicalCanvas(
        builder: (context, _, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            OverlayPanel(
              key: const ValueKey('overlay-ad'),
              w: 900,
              h: 1400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Label(app.t('adTest'), size: 64, color: C.inkSoft),
                  const SizedBox(height: 500),
                  PillButton(
                    app.t('adClose'),
                    key: const ValueKey('btn-ad-close'),
                    w: 420,
                    enabled: _canClose,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
