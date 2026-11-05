import 'dart:async';

import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'data/world_repository.dart';
import 'domain/domain.dart';

void main() {
  runApp(IdleVisitApp(store: SharedPrefsKeyValueStore()));
}

class IdleVisitApp extends StatelessWidget {
  const IdleVisitApp({
    super.key,
    required this.store,
    this.clock = _systemClock,
    this.tick = const Duration(seconds: 1),
  });

  final KeyValueStore store;

  /// 테스트에서 시계를 주입한다. UTC를 돌려줘야 한다.
  final DateTime Function() clock;

  /// 화면을 켜 둔 동안 세계를 진행하는 간격. null이면 자동 진행하지 않는다.
  final Duration? tick;

  static DateTime _systemClock() => DateTime.now().toUtc();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '놀러 와요',
      theme: AppTheme.light(),
      home: HomePage(
        repository: WorldRepository(store),
        clock: clock,
        tick: tick,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.clock,
    required this.tick,
  });

  final WorldRepository repository;
  final DateTime Function() clock;
  final Duration? tick;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  World? _world;
  Duration _clockOffset = Duration.zero;
  Timer? _timer;
  int _tab = 0;
  String _placeId = Catalog.standard.places.first.id;

  Catalog get _catalog => widget.repository.catalog;
  DateTime get _now => widget.clock().add(_clockOffset);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    _clockOffset = await widget.repository.loadClockOffset();
    final loaded = await widget.repository.load(_now);
    if (!mounted) return;
    setState(() => _world = loaded.world);
    await widget.repository.save(loaded.world);
    _announce(loaded.arrivals, whileAway: true);
    if (widget.tick case final tick?) {
      _timer = Timer.periodic(tick, (_) => _advance());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final world = _world;
    if (world == null) return;
    if (state == AppLifecycleState.resumed) {
      _advance();
    } else if (state == AppLifecycleState.paused) {
      widget.repository.save(world);
    }
  }

  void _advance() {
    final world = _world;
    if (world == null) return;
    final arrivals = world.advance(_now);
    setState(() {});
    if (arrivals.isNotEmpty) {
      widget.repository.save(world);
      _announce(arrivals);
    }
  }

  void _announce(List<Arrival> arrivals, {bool whileAway = false}) {
    if (arrivals.isEmpty || !mounted) return;
    final firsts = arrivals.where((a) => a.isFirstVisit).toList();
    final String text;
    if (whileAway) {
      text = firsts.isEmpty
          ? '없는 동안 친구 ${arrivals.length}번이 놀러 왔어요'
          : '없는 동안 새 친구 ${firsts.length}명을 만났어요! 도감을 확인해 보세요';
    } else {
      final last = arrivals.last;
      final c = _catalog.character(last.characterId);
      final place = _catalog.place(last.placeId);
      text = last.isFirstVisit
          ? '${c.emoji} 새 친구 ${c.name}(이)가 ${place.name}에 왔어요!'
          : '${c.emoji} ${c.name}(이)가 ${place.name}에 놀러 왔어요';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _mutate(void Function(World world) change) {
    final world = _world!;
    // 조작 직전까지의 시간을 먼저 흘려야 놓는 시각이 정확하다.
    final arrivals = world.advance(_now);
    setState(() => change(world));
    widget.repository.save(world);
    _announce(arrivals);
  }

  Future<void> _fastForward(Duration by) async {
    _clockOffset += by;
    await widget.repository.saveClockOffset(_clockOffset);
    _advance();
  }

  Future<void> _onSlotTap(Slot slot) async {
    final picked = await showModalBottomSheet<_SlotAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ItemPicker(catalog: _catalog, slot: slot),
    );
    switch (picked) {
      case null:
        return;
      case _Place(:final itemId):
        _mutate((w) => w.placeItem(slot.placeId, slot.index, itemId));
      case _Remove():
        _mutate((w) => w.removeItem(slot.placeId, slot.index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? '놀러 와요' : '도감'),
        actions: [
          // 프로토타입 전용: 기다리지 않고 방문을 확인한다.
          TextButton.icon(
            onPressed: world == null
                ? null
                : () => _fastForward(const Duration(minutes: 30)),
            icon: const Icon(Icons.fast_forward),
            label: const Text('+30분'),
          ),
        ],
      ),
      body: world == null
          ? const Center(child: CircularProgressIndicator())
          : switch (_tab) {
              0 => _PlaceView(
                world: world,
                placeId: _placeId,
                now: _now,
                onPlaceChanged: (id) => setState(() => _placeId = id),
                onSlotTap: _onSlotTap,
              ),
              _ => _CollectionView(world: world),
            },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.park), label: '장소'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: '도감'),
        ],
      ),
    );
  }
}

// ── 장소 ────────────────────────────────────────────────────────────────

class _PlaceView extends StatelessWidget {
  const _PlaceView({
    required this.world,
    required this.placeId,
    required this.now,
    required this.onPlaceChanged,
    required this.onSlotTap,
  });

  final World world;
  final String placeId;
  final DateTime now;
  final ValueChanged<String> onPlaceChanged;
  final ValueChanged<Slot> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final catalog = world.catalog;
    final slots = world.slotsOf(placeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final place in catalog.places)
                ChoiceChip(
                  label: Text('${place.emoji} ${place.name}'),
                  selected: place.id == placeId,
                  onSelected: (_) => onPlaceChanged(place.id),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            children: [
              for (final slot in slots)
                _SlotCard(
                  slot: slot,
                  catalog: catalog,
                  now: now,
                  onTap: () => onSlotTap(slot),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.catalog,
    required this.now,
    required this.onTap,
  });

  final Slot slot;
  final Catalog catalog;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemId = slot.itemId;
    final visit = slot.visit;

    final Widget content;
    if (itemId == null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 32, color: theme.colorScheme.outline),
          const Text('놓기'),
        ],
      );
    } else {
      final item = catalog.item(itemId);
      final visitor = visit == null
          ? null
          : catalog.character(visit.characterId);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 40,
            child: visitor == null
                ? null
                : Text(visitor.emoji, style: const TextStyle(fontSize: 32)),
          ),
          Text(item.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: AppSpacing.xs),
          Text(item.name, style: theme.textTheme.labelLarge),
          Text(
            visitor == null
                ? '누가 올까…'
                : '${visitor.name} · ${_minutesLeft(visit!.leavesAt)}분 더',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }

  int _minutesLeft(DateTime leavesAt) {
    final left = leavesAt.difference(now);
    return (left.inSeconds / 60).ceil().clamp(0, 1 << 30);
  }
}

sealed class _SlotAction {
  const _SlotAction();
}

final class _Place extends _SlotAction {
  const _Place(this.itemId);
  final String itemId;
}

final class _Remove extends _SlotAction {
  const _Remove();
}

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({required this.catalog, required this.slot});

  final Catalog catalog;
  final Slot slot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              slot.isEmpty ? '무엇을 놓을까요?' : '바꾸거나 치우기',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in catalog.items)
                  ActionChip(
                    avatar: Text(item.emoji),
                    label: Text(item.name),
                    onPressed: item.id == slot.itemId
                        ? null
                        : () => Navigator.pop(context, _Place(item.id)),
                  ),
              ],
            ),
          ),
          if (!slot.isEmpty)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, const _Remove()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('치우기'),
            ),
        ],
      ),
    );
  }
}

// ── 도감 ────────────────────────────────────────────────────────────────

class _CollectionView extends StatelessWidget {
  const _CollectionView({required this.world});

  final World world;

  @override
  Widget build(BuildContext context) {
    final catalog = world.catalog;
    final theme = Theme.of(context);
    final collected = world.collection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '${collected.length} / ${catalog.characters.length}마리',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            children: [
              for (final c in catalog.characters)
                Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        collected.containsKey(c.id) ? c.emoji : '❔',
                        style: const TextStyle(fontSize: 32),
                      ),
                      Text(
                        collected.containsKey(c.id) ? c.name : '???',
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(switch (collected[c.id]) {
                        final entry? =>
                          '${c.rarity.label} · ${entry.visitCount}번',
                        null => c.rarity.label,
                      }, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
