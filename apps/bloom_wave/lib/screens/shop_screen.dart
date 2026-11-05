// 상점: 골드 구매(2026-11-05, 소모성 4개 — economy/gold_packs.dart), 꽃 스킨 모음(조각 진행도·장착),
// 스킨 뽑기로 가는 길, 광고 제거.
import 'package:flutter/material.dart';

import '../app.dart';
import '../economy/gold_packs.dart';
import '../economy/skins.dart';
import '../platform/billing.dart';
import '../ui/skin_card.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'gacha_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _busy = false;
  String? _notice;

  /// 스토어가 알려 준 현지 가격 (못 받으면 비어 있고 버튼은 "구매")
  Map<String, String> _prices = const {};
  bool _pricesAsked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pricesAsked) return;
    _pricesAsked = true;
    final app = AppServices.of(context);
    app.billing
        .prices({for (final p in goldPacks) p.id})
        .then((m) {
          if (mounted) setState(() => _prices = m);
        })
        .catchError((_) {});
  }

  Future<void> _buyGold(AppServices app, GoldPack pack) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await app.billing
        .buyConsumable(pack.id)
        .catchError((_) => BuyResult.failed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = switch (r) {
        BuyResult.purchased => app.t('goldBought', {
          'n': withCommas(pack.total),
        }),
        BuyResult.pending => app.t('purchasePending'),
        BuyResult.canceled => app.t('purchaseCanceled'),
        BuyResult.failed => app.t('purchaseFailed'),
      };
    });
    app.changed();
  }

  /// 골드 상품 한 칸: 동전 더미 + 양 + 보너스 + 가격 버튼
  Widget _goldTile(AppServices app, GoldPack pack, int tier) => Container(
    key: ValueKey('gold-pack-${pack.id}'),
    width: 460,
    padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
    decoration: BoxDecoration(
      color: C.panel,
      borderRadius: BorderRadius.circular(44),
      border: pack.bonusPercent > 0
          ? Border.all(color: C.gold, width: 6)
          : null,
    ),
    child: Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 상품이 클수록 동전이 많다 (1~4개)
              for (var k = 0; k <= tier; k++)
                Transform.translate(
                  offset: Offset((k - tier / 2) * 44, (k.isEven ? 0 : -20)),
                  child: const CoinIcon(size: 100),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          withCommas(pack.total),
          key: ValueKey('gold-pack-amount-${pack.id}'),
          style: textStyle(64, weight: FontWeight.w800),
        ),
        Text(
          app.t('goldUnit'),
          style: textStyle(34, color: C.inkSoft, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: pack.bonusPercent > 0
              ? Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: C.gold,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        app.t('goldBonus', {'n': pack.bonusPercent}),
                        style: textStyle(32),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.t('goldBonusAmount', {
                        'base': withCommas(pack.base),
                        'bonus': withCommas(pack.bonus),
                      }),
                      style: textStyle(
                        28,
                        color: C.inkSoft,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 14),
        PillButton(
          _prices[pack.id] ?? app.t('buy'),
          key: ValueKey('btn-buy-${pack.id}'),
          w: 360,
          h: 110,
          size: 40,
          enabled: !_busy,
          onClick: app.sfx.click,
          onTap: () => _buyGold(app, pack),
        ),
      ],
    ),
  );

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

  Future<void> _equip(AppServices app, SkinDef s) async {
    if (await app.save.equipSkin(s.id)) app.changed();
  }

  Widget _skinTile(AppServices app, SkinDef s) {
    final d = app.save.data;
    final unlocked = d.isUnlocked(s);
    final owned = {...?d.skinPieces[s.id]};
    final equipped = d.skin.id == s.id;
    final lang = d.settings.lang;
    return Container(
      key: ValueKey('skin-${s.id}'),
      width: 460,
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(44),
        border: equipped ? Border.all(color: C.accent, width: 8) : null,
      ),
      child: Column(
        children: [
          SkinCard(skin: s, owned: owned, size: 280),
          const SizedBox(height: 22),
          Text(s.name(lang), style: textStyle(44)),
          const SizedBox(height: 6),
          Text(
            unlocked
                ? (s.isDefault
                      ? ''
                      : app.t('pieces', {'n': s.pieces, 'total': s.pieces}))
                : app.t('pieces', {'n': owned.length, 'total': s.pieces}),
            style: textStyle(34, color: C.inkSoft, weight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          PillButton(
            unlocked ? app.t(equipped ? 'equipped' : 'equip') : app.t('locked'),
            key: ValueKey('btn-equip-${s.id}'),
            w: 360,
            h: 110,
            size: 40,
            color: unlocked && !equipped ? C.accent : C.bgDeep,
            textColor: unlocked && !equipped ? Colors.white : C.inkSoft,
            enabled: unlocked && !equipped,
            onClick: app.sfx.click,
            onTap: () => _equip(app, s),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final d = app.save.data;
    return Scaffold(
      body: LogicalCanvas(
        builder: (context, top, bottom) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: top + 220,
              bottom: bottom,
              child: SingleChildScrollView(
                key: const ValueKey('shop-scroll'),
                padding: const EdgeInsets.fromLTRB(60, 10, 60, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.t('goldShop'), style: textStyle(56)),
                    const SizedBox(height: 8),
                    Text(
                      app.t('goldShopSub'),
                      style: textStyle(
                        36,
                        color: C.inkSoft,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      key: const ValueKey('gold-packs'),
                      spacing: 40,
                      runSpacing: 40,
                      children: [
                        for (var i = 0; i < goldPacks.length; i++)
                          _goldTile(app, goldPacks[i], i),
                      ],
                    ),
                    const SizedBox(height: 60),
                    Text(app.t('skinsTitle'), style: textStyle(56)),
                    const SizedBox(height: 8),
                    Text(
                      app.t('skinsSub'),
                      style: textStyle(
                        36,
                        color: C.inkSoft,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      spacing: 40,
                      runSpacing: 40,
                      children: [for (final s in skins) _skinTile(app, s)],
                    ),
                    const SizedBox(height: 50),
                    Center(
                      child: PillButton(
                        app.t('goGacha'),
                        key: const ValueKey('btn-shop-gacha'),
                        w: 960,
                        h: 150,
                        size: 50,
                        color: C.gold,
                        textColor: C.ink,
                        onClick: app.sfx.click,
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GachaScreen(),
                              ),
                            )
                            .then((_) => setState(() {})),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(app.t('removeAds'), style: textStyle(56)),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        PillButton(
                          d.noAds
                              ? app.t('removeAdsOwned')
                              : app.t('removeAds'),
                          key: const ValueKey('btn-shop-remove-ads'),
                          w: 560,
                          h: 140,
                          color: d.noAds ? C.bgDeep : C.accent,
                          textColor: d.noAds ? C.inkSoft : Colors.white,
                          enabled: !d.noAds && !_busy,
                          onClick: app.sfx.click,
                          onTap: () => _buyNoAds(app),
                        ),
                        const Spacer(),
                        PillButton(
                          app.t('restorePurchases'),
                          key: const ValueKey('btn-shop-restore'),
                          w: 360,
                          h: 140,
                          size: 38,
                          color: C.panel,
                          textColor: C.ink,
                          enabled: !_busy,
                          onClick: app.sfx.click,
                          onTap: () => _restore(app),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 상단 바 (스크롤 위에)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: top + 220,
              child: const ColoredBox(color: C.bg),
            ),
            At(
              x: 100,
              y: top + 110,
              w: 140,
              h: 140,
              child: CircleButton(
                key: const ValueKey('btn-back'),
                icon: Icons.chevron_left_rounded,
                tooltip: app.t('home'),
                onClick: app.sfx.click,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            At(
              x: kW / 2,
              y: top + 110,
              h: 100,
              child: Label(app.t('shop'), size: 60),
            ),
            Positioned(
              right: 50,
              top: top + 70,
              child: GoldBadge(key: const ValueKey('shop-gold'), gold: d.gold),
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
                      app.t('ok'),
                      w: 360,
                      onClick: app.sfx.click,
                      onTap: () => setState(() => _notice = null),
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
