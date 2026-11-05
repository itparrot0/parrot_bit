import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/board_model.dart';
import '../economy/economy.dart';
import '../economy/providers.dart';
import '../game/grove_game.dart';
import '../save/save_repository.dart';
import 'sheets.dart';

/// 보드 (홈). 저장을 불러온 뒤 게임을 띄운다.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(loadedGroveProvider)) {
        AsyncData(:final value) => _BoardView(loaded: value),
        AsyncError(:final error) => Scaffold(
          body: Center(child: Text('불러오지 못했어요: $error')),
        ),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      };
}

class _BoardView extends ConsumerStatefulWidget {
  const _BoardView({required this.loaded});

  final LoadedGrove loaded;

  @override
  ConsumerState<_BoardView> createState() => _BoardViewState();
}

/// 게임 ↔ Riverpod 브리지([GroveBridge])를 여기서 구현한다.
class _BoardViewState extends ConsumerState<_BoardView>
    with WidgetsBindingObserver
    implements GroveBridge {
  late final GroveGame _game = GroveGame(
    board: widget.loaded.board,
    bridge: this,
  );

  BoardModel get _board => widget.loaded.board;

  DateTime? _backgroundedAt;

  /// 가속 남은 시간 표시를 갱신한다.
  Timer? _clockTick;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    ref.read(analyticsProvider).logEvent('session_start');
    final gain = widget.loaded.idleGain;
    if (gain.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _welcomeBack(gain));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTick?.cancel();
    super.dispose();
  }

  /// 백그라운드에 있는 동안 Flame 은 멈춰 있으므로, 돌아올 때 그 시간을 한 번에 반영한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = ref.read(clockProvider)();
    switch (state) {
      case AppLifecycleState.paused:
        _backgroundedAt = now;
        _save();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) {
          return;
        }
        ref.read(analyticsProvider).logEvent('session_start');
        final gain = ref
            .read(adRewardsProvider)
            .advanceAway(
              _board,
              since,
              now,
              freeSpace(),
              baseMultiplier: ref.read(economyProvider).outputMultiplier,
            );
        if (gain.isNotEmpty) {
          _welcomeBack(gain);
        }
      default:
        break;
    }
  }

  Future<void> _welcomeBack(Map<Resource, int> gain) async {
    final ads = ref.read(adRewardsProvider);
    final wantsAd = await showWelcomeBack(
      context,
      gain: gain,
      freeSpace: freeSpace(),
      multiplier: ads.config.welcomeMultiplier,
      adsLeftToday: ads.remainingToday(_now()),
    );
    var multiplier = 1;
    if (wantsAd && await _watchAd('welcome_back')) {
      multiplier = ads.config.welcomeMultiplier;
      ref.read(adRewardsProvider.notifier).recordWatch(_now());
    }
    final collected = _game.collectAll();
    ref.read(economyProvider.notifier).depositAll({
      for (final MapEntry(:key, :value) in collected.entries)
        key: value * multiplier,
    });
  }

  /// 보상형 광고 한 편. 끝까지 봤으면 true.
  Future<bool> _watchAd(String placement) async {
    final earned = await ref.read(rewardedAdsProvider).show();
    if (earned) {
      ref.read(analyticsProvider).logEvent('rewarded_ad_completed', {
        'placement': placement,
      });
    }
    return earned;
  }

  Future<void> _boost() async {
    if (!ref.read(adRewardsProvider).canWatch(_now())) {
      return;
    }
    if (await _watchAd('speedup')) {
      ref.read(adRewardsProvider.notifier).startBoost(_now());
    }
  }

  void _save() {
    unawaited(
      ref
          .read(saveRepositoryProvider)
          .write(
            GroveSave(
              board: _board,
              economy: ref.read(economyProvider),
              ads: ref.read(adRewardsProvider),
              savedAt: _now(),
            ),
          ),
    );
  }

  // ---- GroveBridge ----

  @override
  Map<Resource, int> freeSpace() => ref.read(economyProvider).freeSpace;

  @override
  double rateMultiplier() =>
      ref.read(adRewardsProvider).rateMultiplier(_now()) *
      ref.read(economyProvider).outputMultiplier;

  @override
  int deposit(Resource resource, int amount) =>
      ref.read(economyProvider.notifier).deposit(resource, amount);

  @override
  ({Cost cost, bool affordable})? expansionOffer(ExpandDirection direction) {
    final economy = ref.read(economyProvider);
    final cost = economy.expansionCost(direction, _board);
    return cost == null
        ? null
        : (cost: cost, affordable: economy.canAfford(cost));
  }

  @override
  void onBoardChanged() => _save();

  @override
  Future<void> onExpandRequested(ExpandDirection direction) async {
    final economy = ref.read(economyProvider);
    final cost = economy.expansionCost(direction, _board);
    if (cost == null) {
      return;
    }
    final confirmed = await showExpandConfirm(
      context,
      direction: direction,
      board: _board,
      economy: economy,
      cost: cost,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final firstDig = direction == ExpandDirection.dig && !_board.caveEntered;
    final notifier = ref.read(economyProvider.notifier)..pay(cost);
    final analytics = ref.read(analyticsProvider);
    if (direction == ExpandDirection.clear) {
      notifier.markCleared();
      analytics.logEvent('theme_cleared', {'theme': _board.theme.id});
    } else {
      _game.applyExpansion(direction);
      analytics.logEvent('board_expanded', {'direction': direction.name});
    }
    setState(() {});
    if (!mounted) {
      return;
    }
    if (firstDig) {
      analytics.logEvent('cave_entered');
      await showNotice(
        context,
        title: '동굴에 들어섰어요',
        body: '자갈 생성기를 얻었어요. 돌을 키워 광석바위를 만들면 광석이 쌓여요.',
      );
    } else if (direction == ExpandDirection.clear) {
      await showNotice(
        context,
        title: '동굴이 있는 숲을 완성했어요',
        body: '다음 테마는 준비 중이에요. 보드는 계속 쓸 수 있어요.',
      );
    }
  }

  // ---- 화면 ----

  @override
  Widget build(BuildContext context) {
    final economy = ref.watch(economyProvider);
    final ads = ref.watch(adRewardsProvider);
    final now = _now();
    ref.listen(economyProvider, (_, _) {
      _game.refreshHandles();
      _save();
    });
    ref.listen(adRewardsProvider, (_, _) => _save());
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  for (final r in Resource.values)
                    if (r == Resource.wood || _board.caveEntered)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _ResourceChip(
                          key: ValueKey('resource-${r.name}'),
                          label: resourceLabel(r),
                          amount: economy.amountOf(r),
                          capacity: economy.capacity,
                          onTap: _openStorage,
                        ),
                      ),
                  const Spacer(),
                  if (ads.boostActive(now))
                    ActionChip(
                      key: const ValueKey('boost-chip'),
                      avatar: const Icon(Icons.bolt, size: 18),
                      label: Text(boostLabel(ads, now)),
                      onPressed: _openStorage,
                    ),
                  IconButton(
                    onPressed: () => context.goNamed('shop'),
                    icon: const Icon(Icons.storefront_outlined),
                    tooltip: '상점',
                  ),
                  IconButton(
                    onPressed: () => context.goNamed('settings'),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '설정',
                  ),
                ],
              ),
            ),
            Expanded(child: GameWidget(game: _game)),
          ],
        ),
      ),
    );
  }

  void _openStorage() => showStorage(
    context,
    board: _board,
    economy: () => ref.read(economyProvider),
    onUpgrade: () => ref.read(economyProvider.notifier).upgradeStorage(),
    ads: () => ref.read(adRewardsProvider),
    now: _now,
    onBoost: _boost,
    onOpenShop: () => context.goNamed('shop'),
  );
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    super.key,
    required this.label,
    required this.amount,
    required this.capacity,
    required this.onTap,
  });

  final String label;
  final int amount;
  final int capacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = amount >= capacity;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: full ? scheme.errorContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          full ? '$label $amount/$capacity 가득' : '$label $amount/$capacity',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: full ? scheme.onErrorContainer : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
