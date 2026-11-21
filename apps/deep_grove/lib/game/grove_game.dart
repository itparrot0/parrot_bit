import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/board_model.dart';
import '../economy/economy.dart';
import '../economy/hints.dart';
import 'components/board_piece_component.dart';
import 'components/discard_bin_component.dart';
import 'components/expand_target_component.dart';
import 'components/finger_hint_component.dart';
import 'components/generator_component.dart';
import 'components/item_component.dart';
import 'components/producer_component.dart';

/// 디자인 공간에서 셀 한 변 크기.
const double kCellSize = 100;

/// 보드 둘레 여백.
const double _margin = 12;

/// 게임 ↔ 아웃게임(창고·확장·저장) 사이의 유일한 접점 (PRD §8.1).
///
/// Flame 컴포넌트는 Provider를 직접 읽지 않는다. 보드 화면이 이 인터페이스를
/// 구현해 Riverpod 상태와 이어 준다.
abstract interface class GroveBridge {
  /// 지금 창고의 자원별 빈 공간. 산출은 여기까지만 쌓인다.
  Map<Resource, int> freeSpace();

  /// 지금 산출 배율 (광고 산출 가속 중이면 2).
  double rateMultiplier();

  /// 거둔 자원을 창고에 넣는다. 실제로 들어간 양을 돌려준다.
  int deposit(Resource resource, int amount);

  /// [expansion]의 비용과 낼 수 있는지. 지금 할 수 없는 확장이면 null.
  ({Cost cost, bool affordable})? expansionOffer(Expansion expansion);

  /// 잠긴 칸(또는 완주 막대)을 눌렀다 — 확인 시트는 화면이 띄운다.
  void onExpandRequested(Expansion expansion);

  /// 보드 상태가 바뀌었다 (저장 시점).
  void onBoardChanged();

  /// 생성기 탭으로 아이템이 생겼다 (첫 실행 안내 1 끝).
  void onSpawned();

  /// 산출원을 버리기 칸에 놓았다 — 정말 버릴지 묻는다 (아이템은 묻지 않는다).
  Future<bool> confirmDiscard(Producer producer);
}

/// 머지 보드 게임. 규칙 판정은 전부 [BoardModel]에 위임하고,
/// 여기서는 컴포넌트 생성/제거, 좌표 변환, 산출 시간 흐름만 담당한다.
///
/// 최대 보드 왼쪽 위 칸의 왼쪽 위 모서리가 월드 원점이다. 칸 좌표가 최대 보드 기준이라
/// 확장해도 기존 조각의 월드 좌표가 바뀌지 않는다. 화면에는 열린 칸과 다음에 열 수 있는
/// 잠긴 칸만 그리고, 카메라는 그 범위에 맞춘다.
class GroveGame extends FlameGame {
  GroveGame({required this.board, required this.bridge})
    : super(
        camera: CameraComponent.withFixedResolution(width: 400, height: 500),
      );

  final BoardModel board;
  final GroveBridge bridge;

  /// 산출을 몇 초마다 반영하는가. 프레임마다 할 필요가 없다.
  static const double _tickSeconds = 0.25;
  double _sinceTick = 0;

  final Map<CellPos, BoardPieceComponent> _pieces = {};
  final List<Component> _tiles = [];
  final Map<CellPos, RectangleComponent> _tileAt = {};

  /// 드래그 중 밝힌 지대. 없으면 null.
  Zone? _highlighted;

  static const Map<Zone, Color> _tileColor = {
    Zone.forest: Color(0xFF213128),
    Zone.cave: Color(0xFF30281F),
  };
  static const Map<Zone, Color> _tileLit = {
    Zone.forest: Color(0xFF3C6B4A),
    Zone.cave: Color(0xFF6B5436),
  };
  final List<Component> _handles = [];
  final Map<Expansion, ExpandTargetComponent> _handleOf = {};

  /// 지금 띄운 첫 실행 안내와 그 손가락.
  HintTarget? _hint;
  FingerHintComponent? _finger;

  @override
  Color backgroundColor() => const Color(0xFF171B21);

  @override
  Future<void> onLoad() async {
    // 웹은 한글 폴백 폰트를 글자가 필요해진 뒤에 내려받는다. Flutter 위젯은 알아서
    // 다시 그리지만 Flame 글자는 이미 만든 모양을 그대로 쓰므로 직접 다시 만든다.
    PaintingBinding.instance.systemFonts.addListener(_redrawText);
    relayout();
    for (final MapEntry(:key, :value) in board.cells.entries) {
      _addContent(key, value);
    }
  }

  @override
  void onRemove() {
    PaintingBinding.instance.systemFonts.removeListener(_redrawText);
    super.onRemove();
  }

  void _redrawText() {
    _placeBin();
    refreshHandles();
    for (final piece in _pieces.values) {
      if (piece.isLoaded) {
        piece.refreshSkin();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sinceTick += dt;
    if (_sinceTick >= _tickSeconds) {
      board.advance(
        _sinceTick,
        bridge.freeSpace(),
        multiplier: bridge.rateMultiplier(),
      );
      _sinceTick = 0;
    }
  }

  /// 칸의 중심 월드 좌표.
  Vector2 cellCenter(CellPos pos) =>
      Vector2((pos.col + 0.5) * kCellSize, (pos.row + 0.5) * kCellSize);

  /// 월드 좌표가 속한 칸. 보드 밖이면 null.
  CellPos? cellAt(Vector2 point) {
    final pos = (
      col: (point.x / kCellSize).floor(),
      row: (point.y / kCellSize).floor(),
    );
    return board.isInside(pos) ? pos : null;
  }

  /// 열린 칸이 바뀌면 바닥 타일·잠긴 칸·카메라를 다시 잡는다.
  void relayout() {
    _clear(_tiles);
    _tileAt.clear();

    for (final pos in board.unlocked) {
      final tile = RectangleComponent(
        position: cellCenter(pos),
        size: Vector2.all(kCellSize * 0.94),
        anchor: Anchor.center,
        priority: -10,
        paint: Paint(),
      );
      _tileAt[pos] = tile;
      _add(_tiles, tile);
    }
    _paintTiles();
    _placeBin();
    _fitCamera();
    refreshHandles();
  }

  /// 완주 막대 자리를 둘지는 그릴 때마다 바뀔 수 있어서 따로 잡는다.
  bool _clearBarShown = false;

  /// 보드 아래 버리기 칸 높이.
  static const double _binHeight = kCellSize * 0.7;

  DiscardBinComponent? _bin;

  /// 버리기 칸 위치·크기 (보드 바로 아래, 보드 폭).
  Vector2 get _binPosition => Vector2(0, board.rows * kCellSize + _margin);

  void _placeBin() {
    // 다시 만들 때(확장·웹 폰트 로드) 드래그 중 밝힌 상태를 이어받는다.
    final wasLit = _bin?.active ?? false;
    _bin?.removeFromParent();
    _bin = DiscardBinComponent(
      position: _binPosition,
      size: Vector2(board.columns * kCellSize, _binHeight),
    )..active = wasLit;
    world.add(_bin!);
  }

  /// 테스트용: 버리기 칸이 밝혀져 있는가.
  @visibleForTesting
  bool get binLit => _bin?.active ?? false;

  /// 월드 좌표가 버리기 칸 안인가.
  bool isOverBin(Vector2 point) {
    final p = _binPosition;
    return point.x >= p.x &&
        point.x <= p.x + board.columns * kCellSize &&
        point.y >= p.y &&
        point.y <= p.y + _binHeight;
  }

  void _fitCamera() {
    final width = board.columns * kCellSize + _margin * 2;
    final height =
        board.rows * kCellSize +
        _margin +
        _binHeight +
        (_clearBarShown ? kCellSize : 0) +
        _margin * 2;
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(width, height),
    );
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2(-_margin, -_margin);
  }

  /// 첫 실행 안내를 [target]으로 바꾼다 (null이면 지운다). 같은 안내면 그대로 둔다.
  void showHint(HintTarget? target) {
    if (target == _hint && (_finger != null || target == null)) {
      return;
    }
    _hint = target;
    _placeHint();
  }

  void _placeHint() {
    _finger?.removeFromParent();
    _finger = null;
    final point = switch (_hint) {
      null => null,
      CellHint(:final pos) => board.isInside(pos) ? cellCenter(pos) : null,
      // 잠긴 칸 가운데의 비용 글자를 가리지 않게 칸 위쪽을 가리킨다.
      UnlockHint(:final pos) =>
        _handleOf.containsKey(UnlockCell(pos))
            ? cellCenter(pos) - Vector2(0, kCellSize * 0.3)
            : null,
    };
    if (point != null) {
      _finger = FingerHintComponent(target: point);
      world.add(_finger!);
    }
  }

  /// 테스트용: 지금 손가락이 가리키는 안내.
  @visibleForTesting
  HintTarget? get visibleHint => _finger == null ? null : _hint;

  /// [piece]를 집었다: 그 조각이 보너스를 받는 지대 칸을 옅게 밝힌다 (화면 흐름 §5).
  void showBonusZone(BoardPieceComponent piece) {
    final content = board.contentAt(piece.cell);
    _highlighted = content == null ? null : BoardModel.bonusZoneOf(content);
    _paintTiles();
    _bin?.active = board.canDiscard(piece.cell);
  }

  /// 손에서 놓았다: 밝힌 칸을 되돌린다.
  void clearBonusZone() {
    _bin?.active = false;
    if (_highlighted == null) {
      return;
    }
    _highlighted = null;
    _paintTiles();
  }

  void _paintTiles() {
    _tileAt.forEach((pos, tile) {
      final zone = board.zoneOf(pos);
      tile.paint.color = zone == _highlighted
          ? _tileLit[zone]!
          : _tileColor[zone]!;
    });
  }

  /// 테스트용: 지금 밝혀진 칸인가.
  @visibleForTesting
  bool isLit(CellPos pos) => _highlighted == board.zoneOf(pos);

  /// 창고 보유량이 바뀌면 잠긴 칸의 비용·강조와 완주 막대를 다시 그린다.
  void refreshHandles() {
    _clear(_handles);
    _handleOf.clear();
    for (final pos in board.frontier) {
      final offer = bridge.expansionOffer(UnlockCell(pos));
      if (offer == null) continue;
      final zone = board.zoneOf(pos);
      final title = zone == Zone.cave && !board.caveEntered ? '동굴 진입\n' : '';
      _addTarget(
        UnlockCell(pos),
        label: title + _costLines(offer.cost),
        affordable: offer.affordable,
        color: _tileLit[zone]!,
        position: cellCenter(pos) - Vector2.all(kCellSize * 0.47),
        size: Vector2.all(kCellSize * 0.94),
      );
    }
    final clear = bridge.expansionOffer(const ClearTheme());
    if (clear != null) {
      _addTarget(
        const ClearTheme(),
        label: '테마 완주  ${_costLines(clear.cost, separator: ' · ')}',
        affordable: clear.affordable,
        color: const Color(0xFF3E7D4A),
        position: _binPosition + Vector2(0, _binHeight + _margin),
        size: Vector2(board.columns * kCellSize, kCellSize - _margin),
      );
    }
    if ((clear != null) != _clearBarShown) {
      _clearBarShown = clear != null;
      _fitCamera();
    }
    _placeHint();
  }

  static String _costLines(Cost cost, {String separator = '\n'}) => cost.entries
      .map((e) => '${resourceLabel(e.key)} ${e.value}')
      .join(separator);

  void _addTarget(
    Expansion expansion, {
    required String label,
    required bool affordable,
    required Color color,
    required Vector2 position,
    required Vector2 size,
  }) {
    final target = ExpandTargetComponent(
      expansion: expansion,
      label: label,
      affordable: affordable,
      color: color,
      position: position,
      size: size,
    );
    _handleOf[expansion] = target;
    _add(_handles, target);
  }

  void _add(List<Component> group, Component c) {
    group.add(c);
    world.add(c);
  }

  void _clear(List<Component> group) {
    for (final c in group) {
      c.removeFromParent();
    }
    group.clear();
  }

  /// 생성기 탭 처리. 생성에 성공하면 true.
  bool spawnFromGenerator(Generator generator) {
    final pos = board.spawnFrom(generator);
    if (pos == null) {
      return false;
    }
    _addContent(pos, board.contentAt(pos)!, entrance: PieceEntrance.spawn);
    bridge.onSpawned();
    bridge.onBoardChanged();
    return true;
  }

  /// 산출원 탭 처리. 거둔 것이 있으면 true.
  bool harvestAt(CellPos pos) {
    final harvested = board.harvest(pos);
    if (harvested == null) {
      return false;
    }
    final (resource, amount) = harvested;
    final accepted = bridge.deposit(resource, amount);
    if (accepted < amount) {
      // 창고에 안 들어간 몫은 산출원에 돌려준다.
      if (board.contentAt(pos) case ProducerContent(:final producer)) {
        producer.stock += amount - accepted;
      }
    }
    bridge.onBoardChanged();
    return accepted > 0;
  }

  /// 복귀 보상 받기: 모든 산출원을 비운다.
  Map<Resource, int> collectAll() {
    final gains = board.harvestAll();
    bridge.onBoardChanged();
    return gains;
  }

  /// 비용을 낸 뒤 화면이 부른다. 동굴 진입이면 그 칸에 자갈 생성기가 등장한다.
  void applyExpansion(Expansion expansion) {
    if (expansion case UnlockCell(:final pos)) {
      final result = board.unlock(pos);
      if (result.caveGenerator case final gen?) {
        _addContent(gen, board.contentAt(gen)!, entrance: PieceEntrance.spawn);
      }
    }
    relayout();
    bridge.onBoardChanged();
  }

  /// 드래그 종료 판정: 모델 결과에 따라 머지/이동/교체/스냅백을 적용한다.
  void resolveDrop(BoardPieceComponent piece) {
    if (isOverBin(piece.position)) {
      _dropOnBin(piece);
      return;
    }
    final target = cellAt(piece.position);
    final outcome = target == null
        ? MoveOutcome.rejected
        : board.tryMove(piece.cell, target);

    switch (outcome) {
      case MoveOutcome.moved:
        _pieces.remove(piece.cell);
        piece.cell = target!;
        _pieces[target] = piece;
        piece.settleTo(cellCenter(target));
      case MoveOutcome.swapped:
        final origin = piece.cell;
        final other = _pieces.remove(target!);
        _pieces.remove(origin);
        if (other != null) {
          other.cell = origin;
          _pieces[origin] = other;
          other.settleTo(cellCenter(origin));
        }
        piece.cell = target;
        _pieces[target] = piece;
        piece.settleTo(cellCenter(target));
      case MoveOutcome.merged:
        final consumed = _pieces.remove(target!);
        _pieces.remove(piece.cell);
        consumed?.removeFromParent();
        piece.removeFromParent();
        _addContent(
          target,
          board.contentAt(target)!,
          entrance: PieceEntrance.merge,
        );
      case MoveOutcome.rejected:
        piece.settleTo(cellCenter(piece.cell));
    }
    if (outcome != MoveOutcome.rejected) {
      bridge.onBoardChanged();
    }
  }

  /// 버리기 칸에 놓았다: 생성기는 거부, 아이템은 바로, 산출원은 물어보고 버린다.
  Future<void> _dropOnBin(BoardPieceComponent piece) async {
    final pos = piece.cell;
    final content = board.contentAt(pos);
    if (content == null || !board.canDiscard(pos)) {
      piece.settleTo(cellCenter(pos));
      piece.shake();
      return;
    }
    if (content case ProducerContent(:final producer)) {
      piece.settleTo(cellCenter(pos));
      if (!await bridge.confirmDiscard(producer)) {
        return;
      }
      // 묻는 사이 옮겨졌으면 그만둔다.
      if (board.contentAt(pos) != content) {
        return;
      }
    }
    final result = board.discard(pos)!;
    if (result.harvested case (final r, final amount)) {
      bridge.deposit(r, amount);
    }
    _pieces.remove(pos)?.removeFromParent();
    bridge.onBoardChanged();
  }

  void _addContent(
    CellPos pos,
    CellContent content, {
    PieceEntrance entrance = PieceEntrance.none,
  }) {
    final piece = switch (content) {
      ItemContent(:final item) => ItemComponent(
        cell: pos,
        item: item,
        entrance: entrance,
      ),
      GeneratorContent(:final generator) => GeneratorComponent(
        cell: pos,
        generator: generator,
        entrance: entrance,
      ),
      ProducerContent(:final producer) => ProducerComponent(
        cell: pos,
        producer: producer,
        entrance: entrance,
      ),
    };
    _pieces[pos] = piece;
    world.add(piece);
  }

  /// 테스트용: 칸의 조각 컴포넌트.
  @visibleForTesting
  BoardPieceComponent? pieceAt(CellPos pos) => _pieces[pos];
}

/// 자원 표시 이름.
String resourceLabel(Resource r) => switch (r) {
  Resource.wood => '목재',
  Resource.ore => '광석',
};
