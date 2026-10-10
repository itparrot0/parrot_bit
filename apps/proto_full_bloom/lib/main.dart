import 'package:core_ui/core_ui.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'domain/domain.dart';
import 'game/bloom_game.dart';
import 'game/bloom_palette.dart';
import 'levels/handmade_levels.dart';

void main() {
  runApp(const GardenGrowApp());
}

class GardenGrowApp extends StatelessWidget {
  const GardenGrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garden Grow',
      theme: AppTheme.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int _levelIndex = 0;
  late BloomGame _game = BloomGame(level: HandmadeLevels.all[_levelIndex]);

  void _loadLevel(int index) {
    setState(() {
      _levelIndex = index;
      _game = BloomGame(level: HandmadeLevels.all[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = HandmadeLevels.all[_levelIndex];

    return Scaffold(
      backgroundColor: BloomPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _LevelBar(
              levels: HandmadeLevels.all,
              selected: _levelIndex,
              onSelect: _loadLevel,
            ),
            ValueListenableBuilder<BloomStats>(
              valueListenable: _game.stats,
              builder: (context, stats, _) => _StatusBar(
                level: level,
                stats: stats,
                onUndo: stats.canUndo ? _game.undo : null,
                onRestart: _game.restart,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                // 보드가 바뀌면 GameWidget도 새로 만들어야 한다.
                child: GameWidget(key: ValueKey(_game), game: _game),
              ),
            ),
            ValueListenableBuilder<BloomStats>(
              valueListenable: _game.stats,
              builder: (context, stats, _) => _CanTray(game: _game),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.levels,
    required this.selected,
    required this.onSelect,
  });

  final List<BloomLevel> levels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (var index = 0; index < levels.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(levels[index].name),
                selected: index == selected,
                onSelected: (_) => onSelect(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.level,
    required this.stats,
    required this.onUndo,
    required this.onRestart,
  });

  final BloomLevel level;
  final BloomStats stats;
  final VoidCallback? onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final message = switch ((stats.isWon, stats.isDeadlocked)) {
      (true, _) => 'Full Bloom! ${stats.watered}번에 다 피웠다',
      (_, true) => '교착 — 둘 수 있는 수가 없다',
      _ => '${stats.bloomed} / ${stats.total}칸',
    };
    final color = switch ((stats.isWon, stats.isDeadlocked)) {
      (true, _) => BloomPalette.of(BloomColor.green),
      (_, true) => BloomPalette.of(BloomColor.red),
      _ => Colors.white70,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
            tooltip: '한 수 되돌리기',
          ),
          IconButton(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            tooltip: '재시작',
          ),
        ],
      ),
    );
  }
}

/// 활성화 슬롯 + 레인들.
class _CanTray extends StatelessWidget {
  const _CanTray({required this.game});

  final BloomGame game;

  @override
  Widget build(BuildContext context) {
    final board = game.board;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '활성화',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(width: AppSpacing.xs),
              for (var slot = 0; slot < board.activeSlots.length; slot++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: _ActiveSlotChip(
                    can: board.activeSlots[slot],
                    enabled: board.canUseActive(slot),
                    onTap: () => game.useActive(slot),
                    onPreview: (pressed) {
                      final can = board.activeSlots[slot];
                      game.setPreview(
                        pressed && can != null
                            ? (color: can.color, remaining: can.remaining)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 레인은 세로 기둥이다 — 맨 앞이 위. 기본은 전부 공개이고,
          // 숨김 표시된 물뿌리개만 맨 앞에 올 때까지 가려진다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var lane = 0; lane < board.laneCount; lane++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _LaneColumn(
                    views: board.laneView(lane),
                    canTake: board.canTakeFromLane(lane),
                    onTake: () => game.takeFromLane(lane),
                    onPreview: (pressed) {
                      final front = board.laneFront(lane);
                      game.setPreview(
                        pressed && front != null
                            ? (color: front.color, remaining: front.count)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 활성화 슬롯 한 칸. 주차된 물뿌리개는 대상이 생기면 탭해서 재개한다.
class _ActiveSlotChip extends StatelessWidget {
  const _ActiveSlotChip({
    required this.can,
    required this.enabled,
    required this.onTap,
    required this.onPreview,
  });

  final WateringCan? can;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<bool> onPreview;

  @override
  Widget build(BuildContext context) {
    final current = can;
    if (current == null) {
      return Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: BloomPalette.tile.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: Colors.white12),
        ),
      );
    }

    final color = BloomPalette.of(current.color);
    return GestureDetector(
      onTapDown: (_) => onPreview(true),
      onTapCancel: () => onPreview(false),
      onTap: () {
        onPreview(false);
        if (enabled) {
          onTap();
        }
      },
      child: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.9 : 0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: enabled ? Colors.white54 : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '×${current.remaining}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
            if (!enabled)
              const Text(
                '주차',
                style: TextStyle(fontSize: 9, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}

/// 레인 한 기둥 — 맨 앞(맨 위)만 꺼낼 수 있다.
///
/// 기본은 전부 공개(색·개수)이고, 숨김 표시된 물뿌리개만 맨 앞에 올 때까지
/// `?` 덮개로 가려진다.
class _LaneColumn extends StatelessWidget {
  const _LaneColumn({
    required this.views,
    required this.canTake,
    required this.onTake,
    required this.onPreview,
  });

  final List<LaneCanView> views;
  final bool canTake;
  final VoidCallback onTake;
  final ValueChanged<bool> onPreview;

  static const double _width = 60;

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      // 빈 레인 — 자리만 남긴다.
      return Container(
        width: _width,
        height: 44,
        decoration: BoxDecoration(
          color: BloomPalette.tile.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: Colors.white12),
        ),
      );
    }

    final front = views.first.spec;
    final frontColor = BloomPalette.of(front.color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 맨 앞 — 꺼낼 수 있는 유일한 자리. 맨 앞에 오면 항상 공개된다.
        GestureDetector(
          onTapDown: (_) => onPreview(true),
          onTapCancel: () => onPreview(false),
          onTap: () {
            onPreview(false);
            if (canTake) {
              onTake();
            }
          },
          child: Container(
            width: _width,
            height: 44,
            decoration: BoxDecoration(
              color: frontColor.withValues(alpha: canTake ? 0.9 : 0.35),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: canTake ? Colors.white54 : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '×${front.count}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: canTake ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
        // 아랫줄 — 공개면 색·개수를, 숨김이면 ? 덮개를 그린다.
        for (final view in views.skip(1))
          view.revealed
              ? Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: _width,
                  height: 30,
                  decoration: BoxDecoration(
                    color: BloomPalette.of(
                      view.spec.color,
                    ).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '×${view.spec.count}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: _width,
                  height: 30,
                  decoration: BoxDecoration(
                    color: BloomPalette.tile,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                    ),
                  ),
                ),
      ],
    );
  }
}
