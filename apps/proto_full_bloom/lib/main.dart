import 'package:core_ui/core_ui.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'domain/domain.dart';
import 'game/bloom_game.dart';
import 'game/bloom_palette.dart';
import 'levels/handmade_levels.dart';

void main() {
  runApp(const ProtoFullBloomApp());
}

class ProtoFullBloomApp extends StatelessWidget {
  const ProtoFullBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '만개',
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
              builder: (context, stats, _) => _SlotBar(game: _game),
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
      (true, _) => '만개! ${stats.watered}번에 다 피웠다',
      (_, true) => '교착 — 쓸 수 있는 물뿌리개가 없다',
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

/// 활성화 슬롯과 대기열 (PRD §3.6).
class _SlotBar extends StatelessWidget {
  const _SlotBar({required this.game});

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
              for (var index = 0; index < board.slots.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _SlotButton(
                      can: board.slots[index],
                      enabled: board.canUseSlot(index),
                      onTap: () => game.useSlot(index),
                      onPreview: (pressed) =>
                          game.setPreview(pressed ? index : null),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _PendingRow(cans: board.pendingCans),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.can,
    required this.enabled,
    required this.onTap,
    required this.onPreview,
  });

  final WateringCan? can;
  final bool enabled;
  final VoidCallback onTap;

  /// 누르고 있는 동안 true. 보드에 이 물뿌리개가 피울 칸을 번호로 띄운다.
  final ValueChanged<bool> onPreview;

  @override
  Widget build(BuildContext context) {
    final current = can;
    if (current == null) {
      return Container(
        height: 62,
        decoration: BoxDecoration(
          color: BloomPalette.tile.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      );
    }

    final color = BloomPalette.of(current.color);
    return GestureDetector(
      // 누르고 있는 동안 어느 칸이 피는지 보드에 표시한다.
      onTapDown: (_) => onPreview(true),
      onTapCancel: () => onPreview(false),
      onTap: () {
        onPreview(false);
        if (enabled) {
          onTap();
        }
      },
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.9 : 0.22),
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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
            if (!enabled)
              const Text(
                '쓸 곳 없음',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.cans});

  final List<CanSpec> cans;

  @override
  Widget build(BuildContext context) {
    if (cans.isEmpty) {
      return const Text(
        '대기열 비어 있음',
        style: TextStyle(fontSize: 11, color: Colors.white38),
      );
    }
    return Row(
      children: [
        const Text(
          '대기열',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final can in cans)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: BloomPalette.of(can.color).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×${can.count}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
