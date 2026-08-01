import 'package:core_ui/core_ui.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/merge_game.dart';

void main() {
  runApp(const ProtoMergeApp());
}

class ProtoMergeApp extends StatelessWidget {
  const ProtoMergeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'proto_merge',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
  final MergeGame _game = MergeGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: ValueListenableBuilder<BoardStats>(
                valueListenable: _game.stats,
                builder: (context, value, _) => Row(
                  children: [
                    _StatChip(label: '최고 레벨', value: '${value.highestLevel}'),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(label: '머지', value: '${value.mergeCount}'),
                    const Spacer(),
                    IconButton(
                      onPressed: _game.resetGame,
                      icon: const Icon(Icons.refresh),
                      tooltip: '리셋',
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: GameWidget(game: _game)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: colorScheme.onSecondaryContainer),
      ),
    );
  }
}
