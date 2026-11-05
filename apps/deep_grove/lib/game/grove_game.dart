import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/board_model.dart';
import '../economy/economy.dart';
import '../economy/hints.dart';
import 'components/board_piece_component.dart';
import 'components/expand_handle_component.dart';
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

  /// [direction] 확장의 다음 비용과 낼 수 있는지. 그 방향이 끝났으면 null.
  ({Cost cost, bool affordable})? expansionOffer(ExpandDirection direction);

  /// 손잡이를 눌렀다 — 확인 시트는 화면이 띄운다.
  void onExpandRequested(ExpandDirection direction);

  /// 보드 상태가 바뀌었다 (저장 시점).
  void onBoardChanged();

  /// 생성기 탭으로 아이템이 생겼다 (첫 실행 안내 1 끝).
  void onSpawned();
}

/// 머지 보드 게임. 규칙 판정은 전부 [BoardModel]에 위임하고,
/// 여기서는 컴포넌트 생성/제거, 좌표 변환, 산출 시간 흐름만 담당한다.
///
/// 보드 왼쪽 위 칸의 왼쪽 위 모서리가 월드 원점이다. 확장은 오른쪽·아래로만
/// 붙으므로 기존 조각의 월드 좌표가 바뀌지 않는다.
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
  final Map<ExpandDirection, ExpandHandleComponent> _handleOf = {};

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

  /// 보드 크기가 바뀌면 바닥 타일·손잡이·카메라를 다시 잡는다.
  void relayout() {
    _clear(_tiles);
    _tileAt.clear();

    for (var row = 0; row < board.rows; row++) {
      for (var col = 0; col < board.columns; col++) {
        final pos = (col: col, row: row);
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
    }
    _paintTiles();

    final boardW = board.columns * kCellSize;
    final boardH = board.rows * kCellSize;
    final width = boardW + kCellSize + _margin * 2;
    final height = boardH + kCellSize + _margin * 2;
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(width, height),
    );
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2(-_margin, -_margin);
    refreshHandles();
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
      HandleHint(:final direction) => switch (_handleOf[direction]) {
        // 라벨(가운데)을 가리지 않게 빈 쪽을 가리킨다: 세로 손잡이는 위, 가로 손잡이는 왼쪽.
        final h? =>
          h.position +
              (h.size.y > h.size.x
                  ? Vector2(h.size.x / 2, h.size.y * 0.2)
                  : Vector2(h.size.x * 0.12, h.size.y / 2)),
        null => null,
      },
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
  }

  /// 손에서 놓았다: 밝힌 칸을 되돌린다.
  void clearBonusZone() {
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

  /// 창고 보유량이 바뀌면 손잡이의 비용·강조를 다시 그린다.
  void refreshHandles() {
    _clear(_handles);
    _handleOf.clear();
    final boardW = board.columns * kCellSize;
    final boardH = board.rows * kCellSize;
    _addHandle(
      ExpandDirection.widen,
      position: Vector2(boardW + _margin, 0),
      size: Vector2(kCellSize - _margin, boardH),
      vertical: true,
    );
    // 아래 손잡이는 하향 확장이 끝나면 테마 완주 손잡이로 바뀐다.
    final bottom = board.canDig ? ExpandDirection.dig : ExpandDirection.clear;
    _addHandle(
      bottom,
      position: Vector2(0, boardH + _margin),
      size: Vector2(boardW, kCellSize - _margin),
      vertical: false,
    );
    _placeHint();
  }

  void _addHandle(
    ExpandDirection direction, {
    required Vector2 position,
    required Vector2 size,
    required bool vertical,
  }) {
    final offer = bridge.expansionOffer(direction);
    if (offer == null) {
      return;
    }
    final title = switch (direction) {
      ExpandDirection.widen => '넓히기',
      ExpandDirection.dig => board.caveEntered ? '파기' : '동굴 진입',
      ExpandDirection.clear => '테마 완주',
    };
    final cost = offer.cost.entries
        .map((e) => '${resourceLabel(e.key)} ${e.value}')
        .join(vertical ? '\n' : ' · ');
    final handle = ExpandHandleComponent(
      direction: direction,
      label: vertical ? '$title\n\n$cost' : '$title  $cost',
      affordable: offer.affordable,
      position: position,
      size: size,
    );
    _handleOf[direction] = handle;
    _add(_handles, handle);
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

  /// 비용을 낸 뒤 화면이 부른다. 동굴 진입이면 자갈 생성기가 등장한다.
  void applyExpansion(ExpandDirection direction) {
    switch (direction) {
      case ExpandDirection.widen:
        board.widen();
      case ExpandDirection.dig:
        final result = board.dig();
        if (result.caveGenerator case final pos?) {
          _addContent(
            pos,
            board.contentAt(pos)!,
            entrance: PieceEntrance.spawn,
          );
        }
      case ExpandDirection.clear:
        break;
    }
    relayout();
    bridge.onBoardChanged();
  }

  /// 드래그 종료 판정: 모델 결과에 따라 머지/이동/교체/스냅백을 적용한다.
  void resolveDrop(BoardPieceComponent piece) {
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
