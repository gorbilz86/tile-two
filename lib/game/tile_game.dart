import 'dart:async';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tile_two/components/board_component.dart';
import 'package:tile_two/components/slot_bar.dart';
import 'package:tile_two/components/tile_component.dart';
import 'package:tile_two/game/fruit_sprite_sheet.dart';
import 'package:tile_two/game/level_manager.dart';
import 'package:tile_two/game/save_game_repository.dart';

class TileGame extends FlameGame {
  final double footerReservedHeight;
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> undoBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<int> shuffleBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<int> hintBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<String> levelBannerNotifier = ValueNotifier<String>('Level 1');
  final ValueNotifier<double> matchFlashNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> isGameOverNotifier = ValueNotifier<bool>(false);
  final List<String> tileTypes = [
    'fruit_01',
    'fruit_02',
    'fruit_03',
    'fruit_04',
    'fruit_05',
    'fruit_06',
    'fruit_07',
    'fruit_08',
    'fruit_09',
    'fruit_10',
    'fruit_11',
    'fruit_12',
  ];

  late final BoardComponent board;
  late final SlotBarComponent slotBar;
  late final LevelManager levelManager;
  late final FruitSpriteSheet fruitSpriteSheet;
  late final SaveGameRepository saveGameRepository;
  late SaveGameData _saveData;
  final Map<String, int> _typeToSpriteIndex = const {
    'fruit_01': 0,
    'fruit_02': 1,
    'fruit_03': 2,
    'fruit_04': 3,
    'fruit_05': 4,
    'fruit_06': 5,
    'fruit_07': 8,
    'fruit_08': 9,
    'fruit_09': 10,
    'fruit_10': 11,
    'fruit_11': 12,
    'fruit_12': 13,
  };

  final List<TileComponent> _slotTiles = [];
  final List<_MoveRecord> _history = [];
  final List<_DtWait> _pendingWaits = [];
  final math.Random _random = math.Random();
  bool _busy = false;
  bool _tapInFlight = false;
  bool _componentsReady = false;
  int _comboCounter = 0;
  double _tileSize = 64;
  final double _spacing = 4;

  TileGame({required this.footerReservedHeight});

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/images/';
    fruitSpriteSheet = await FruitSpriteSheet.load(images: images);

    camera.viewport = MaxViewport();

    levelManager = LevelManager(tileTypes: tileTypes);
    saveGameRepository = SaveGameRepository();
    _saveData = await saveGameRepository.load();
    _applySaveData();
    board = BoardComponent(
      onTopTileTapped: _handleBoardTap,
      tileSize: _tileSize,
      spacing: _spacing,
    );
    slotBar = SlotBarComponent(
      slotSize: _tileSize,
      spacing: _spacing,
    );

    await add(board);
    await add(slotBar);
    _componentsReady = true;
    _relayout(size);
    await _loadLevel(_saveData.currentLevel);
  }

  Sprite fruitSpriteByIndex(int index) {
    return fruitSpriteSheet.spriteByIndex(index);
  }

  int spriteIndexForType(String type) {
    final index = _typeToSpriteIndex[type];
    if (index == null) {
      throw ArgumentError.value(type, 'type', 'Unsupported tile type');
    }
    return index;
  }

  Sprite spriteForType(String type) {
    return fruitSpriteByIndex(spriteIndexForType(type));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _relayout(size);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pendingWaits.isEmpty) {
      return;
    }
    for (var i = _pendingWaits.length - 1; i >= 0; i--) {
      final wait = _pendingWaits[i];
      wait.remaining -= dt;
      if (wait.remaining <= 0) {
        _pendingWaits.removeAt(i);
        if (!wait.completer.isCompleted) {
          wait.completer.complete();
        }
      }
    }
  }

  Future<void> _loadLevel(int level) async {
    _busy = true;
    try {
      _slotTiles.clear();
      _history.clear();
      _comboCounter = 0;
      matchFlashNotifier.value = 0;
      isGameOverNotifier.value = false;
      final safeLevel = level.clamp(1, 50);
      levelNotifier.value = safeLevel;
      levelBannerNotifier.value = 'Level $safeLevel';
      _saveData = _saveData.copyWith(currentLevel: safeLevel);
      await saveGameRepository.save(_saveData);
      final layout = levelManager.build(level: safeLevel, columns: board.columns, rows: board.rows);
      await board.loadLayout(layout);
      await board.playLevelStartIntro();
      _updateFailState();
    } finally {
      _busy = false;
    }
  }

  void _relayout(Vector2 canvasSize) {
    if (!_componentsReady || canvasSize.x <= 0 || canvasSize.y <= 0) {
      return;
    }
    final baseTileSize = canvasSize.x / 6.4;
    _tileSize = baseTileSize * 0.92;
    final slotSize = _tileSize * 0.9;
    const slotTopY = 84.0;
    slotBar.updateLayout(
      topLeft: Vector2(
        (canvasSize.x - ((slotBar.slotCount * slotSize) + ((slotBar.slotCount - 1) * _spacing))) / 2,
        slotTopY,
      ),
      newSlotSize: slotSize,
      newSpacing: _spacing,
    );

    final boardWidth = (board.columns * _tileSize) + ((board.columns - 1) * _spacing);
    final boardHeight = (board.rows * _tileSize) + ((board.rows - 1) * _spacing);
    final playAreaTop = slotBar.position.y + slotSize + 24;
    final playAreaBottom = canvasSize.y - footerReservedHeight - 20;
    final maxTop = (playAreaBottom - boardHeight).clamp(playAreaTop, canvasSize.y)
        .toDouble();
    final top = (((playAreaTop + playAreaBottom) - boardHeight) / 2)
        .clamp(playAreaTop, maxTop)
        .toDouble();

    board.applyLayout(
      newTileSize: _tileSize,
      newSpacing: _spacing,
      topLeft: Vector2((canvasSize.x - boardWidth) / 2, top),
    );

    for (var i = 0; i < _slotTiles.length; i++) {
      _slotTiles[i].relayout(
        newTileSize: slotSize,
        newTopLeft: slotBar.slotTopLeft(i),
        newPriority: 3000 + i,
      );
    }
  }

  Future<void> _handleBoardTap(TileComponent tile) async {
    if (_busy || _tapInFlight || isGameOverNotifier.value || _slotTiles.length >= slotBar.slotCount) {
      return;
    }
    _tapInFlight = true;
    final originRow = tile.row;
    final originColumn = tile.column;
    final worldTopLeft = board.worldTopLeftOf(tile);
    final consumed = board.consumeTopTile(tile);
    if (!consumed) {
      _tapInFlight = false;
      return;
    }

    try {
      tile
        ..isInTransit = true
        ..setTapEnabled(false)
        ..position = worldTopLeft
        ..priority = 3000;
      tile.relayout(
        newTileSize: slotBar.slotSize,
        newTopLeft: worldTopLeft,
        newPriority: 3000,
      );
      add(tile);

      final slotIndex = _slotTiles.length;
      final target = slotBar.slotTopLeft(slotIndex);
      tile.add(
        SequenceEffect(
          [
            ScaleEffect.to(
              Vector2.all(1.1),
              EffectController(duration: 0.07, curve: Curves.easeOut),
            ),
            ScaleEffect.to(
              Vector2.all(1),
              EffectController(duration: 0.1, curve: Curves.easeInOut),
            ),
          ],
        ),
      );
      tile.add(
        MoveEffect.to(
          target,
          EffectController(duration: 0.25, curve: Curves.easeOutBack),
        ),
      );
      await _wait(0.25);
      tile.add(
        SequenceEffect(
          [
            ScaleEffect.to(
              Vector2.all(1.06),
              EffectController(duration: 0.06, curve: Curves.easeOut),
            ),
            ScaleEffect.to(
              Vector2.all(1),
              EffectController(duration: 0.1, curve: Curves.easeInOut),
            ),
          ],
        ),
      );
      tile.isInTransit = false;
      _slotTiles.add(tile);
      _history.add(
        _MoveRecord(
          tile: tile,
          row: originRow,
          column: originColumn,
        ),
      );

      await _resolveMatches();
      if (board.isEmpty) {
        await _checkLevelProgression();
        return;
      }
      _updateFailState();
    } finally {
      _tapInFlight = false;
    }
  }

  Future<void> _resolveMatches() async {
    if (_firstMatchType() == null) {
      _comboCounter = 0;
      return;
    }

    _busy = true;
    try {
      while (true) {
        final type = _firstMatchType();
        if (type == null) {
          _comboCounter = 0;
          break;
        }

        final matched = _slotTiles.where((tile) => tile.type == type).take(3).toList();
        _comboCounter += 1;
        _triggerMatchFlash(_comboCounter);
        for (var i = 0; i < matched.length; i++) {
          final tile = matched[i];
          _spawnMatchBurst(tile.position + (tile.size / 2));
          tile.add(
            SequenceEffect(
              [
                ScaleEffect.to(
                  Vector2.all(1.2),
                  EffectController(
                    duration: 0.09,
                    curve: Curves.easeOutBack,
                    startDelay: i * 0.03,
                  ),
                ),
                ScaleEffect.to(
                  Vector2.zero(),
                  EffectController(
                    duration: 0.16,
                    curve: Curves.easeInBack,
                  ),
                ),
                OpacityEffect.to(
                  0,
                  EffectController(duration: 0.08),
                ),
              ],
            ),
          );
        }
        await _wait(0.31);

        for (final tile in matched) {
          _slotTiles.remove(tile);
          _history.removeWhere((record) => record.tile == tile);
          tile.removeFromParent();
        }
        await _shiftSlotTilesLeft();
        await _wait((35 + (_comboCounter * 20)) / 1000);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _shiftSlotTilesLeft() async {
    for (var i = 0; i < _slotTiles.length; i++) {
      final tile = _slotTiles[i];
      final target = slotBar.slotTopLeft(i);
      tile.add(
        MoveEffect.to(
          target,
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
      tile.priority = 3000 + i;
    }
    await _wait(0.2);
  }

  Future<void> _checkLevelProgression() async {
    if (!board.isEmpty) {
      return;
    }
    _busy = true;
    levelBannerNotifier.value = 'Level ${levelNotifier.value} Complete';
    await _wait(0.7);
    for (final tile in _slotTiles) {
      tile.removeFromParent();
    }
    _slotTiles.clear();
    final nextLevel = levelNotifier.value >= 50 ? 1 : levelNotifier.value + 1;
    _saveData = _saveData.copyWith(
      currentLevel: nextLevel,
      completedLevels: math.max(_saveData.completedLevels, levelNotifier.value),
      streak: _saveData.streak + 1,
    );
    _applySaveData();
    await saveGameRepository.save(_saveData);
    await _loadLevel(nextLevel);
    _busy = false;
  }

  Future<void> shuffleBoard() async {
    if (_busy || _tapInFlight || isGameOverNotifier.value) {
      return;
    }
    _busy = true;
    final shuffled = await board.shuffleRemainingTiles();
    _busy = false;
    if (shuffled && _saveData.inventory.shuffle > 0) {
      _saveData = _saveData.copyWith(
        inventory: _saveData.inventory.copyWith(
          shuffle: _saveData.inventory.shuffle - 1,
        ),
      );
      _applySaveData();
      await saveGameRepository.save(_saveData);
    }
    _updateFailState();
  }

  void provideHint() {
    if (_busy || _tapInFlight || isGameOverNotifier.value) {
      return;
    }
    final hint = _bestHintTiles();
    if (hint.isEmpty) {
      return;
    }
    board.highlightTiles(hint, seconds: 1);
    if (_saveData.inventory.hint > 0) {
      _saveData = _saveData.copyWith(
        inventory: _saveData.inventory.copyWith(
          hint: _saveData.inventory.hint - 1,
        ),
      );
      _applySaveData();
      unawaited(saveGameRepository.save(_saveData));
    }
  }

  Future<void> undoLastMove() async {
    if (_busy || _tapInFlight || _history.isEmpty || _slotTiles.isEmpty) {
      return;
    }
    final recordIndex = _history.lastIndexWhere((record) => _slotTiles.contains(record.tile));
    if (recordIndex < 0) {
      return;
    }
    final record = _history.removeAt(recordIndex);
    _busy = true;
    _slotTiles.remove(record.tile);
    await _shiftSlotTilesLeft();
    final target = board.worldPositionForRestore(
      row: record.row,
      column: record.column,
    );
    record.tile
      ..isInTransit = true
      ..setTapEnabled(false);
    record.tile.add(
      MoveEffect.to(
        target,
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
    await _wait(0.25);
    record.tile.isInTransit = false;
    record.tile.removeFromParent();
    board.restoreTile(
      tile: record.tile,
      row: record.row,
      column: record.column,
    );
    if (_saveData.inventory.undo > 0) {
      _saveData = _saveData.copyWith(
        inventory: _saveData.inventory.copyWith(
          undo: _saveData.inventory.undo - 1,
        ),
      );
      _applySaveData();
      await saveGameRepository.save(_saveData);
    }
    _updateFailState();
    _busy = false;
  }

  Future<void> retryCurrentLevel() async {
    if (_busy || _tapInFlight) {
      return;
    }
    _busy = true;
    for (final tile in _slotTiles) {
      tile.removeFromParent();
    }
    _slotTiles.clear();
    _history.clear();
    isGameOverNotifier.value = false;
    await _loadLevel(levelNotifier.value);
    _busy = false;
  }

  void _spawnMatchBurst(Vector2 center) {
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 12,
          lifespan: 0.28,
          generator: (index) {
            final angle = (math.pi * 2 * index) / 12;
            final speed = 45 + _random.nextDouble() * 60;
            return AcceleratedParticle(
              acceleration: Vector2(0, 120),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              position: center.clone(),
              child: CircleParticle(
                radius: 1.5 + _random.nextDouble() * 1.8,
                paint: Paint()..color = const Color(0xFFFFE082),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _triggerMatchFlash(int combo) async {
    final peak = (0.12 + (combo * 0.03)).clamp(0.12, 0.24).toDouble();
    matchFlashNotifier.value = peak;
    await _wait(0.046);
    matchFlashNotifier.value = peak * 0.35;
    await _wait(0.042);
    matchFlashNotifier.value = 0;
  }

  String? _firstMatchType() {
    final counts = <String, int>{};
    for (final tile in _slotTiles) {
      counts.update(tile.type, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      if (entry.value >= 3) {
        return entry.key;
      }
    }
    return null;
  }

  List<TileComponent> _bestHintTiles() {
    final slotTypeCount = <String, int>{};
    for (final tile in _slotTiles) {
      slotTypeCount.update(tile.type, (value) => value + 1, ifAbsent: () => 1);
    }
    final playable = board.playableTopTiles();
    if (playable.isEmpty) {
      return const [];
    }
    final playableByType = <String, List<TileComponent>>{};
    for (final tile in playable) {
      playableByType.putIfAbsent(tile.type, () => []).add(tile);
    }
    String? bestType;
    int bestNeed = 4;
    int bestSlotCount = -1;
    int bestPlayableCount = -1;
    for (final entry in playableByType.entries) {
      final slotCount = slotTypeCount[entry.key] ?? 0;
      final playableCount = entry.value.length;
      if (slotCount + playableCount < 3) {
        continue;
      }
      final need = (3 - slotCount).clamp(1, 3);
      final isBetter = need < bestNeed ||
          (need == bestNeed && slotCount > bestSlotCount) ||
          (need == bestNeed && slotCount == bestSlotCount && playableCount > bestPlayableCount);
      if (isBetter) {
        bestNeed = need;
        bestType = entry.key;
        bestSlotCount = slotCount;
        bestPlayableCount = playableCount;
      }
    }
    if (bestType != null) {
      return playableByType[bestType]!.take(bestNeed).toList();
    }
    final fallbackType = playableByType.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b).key;
    return [playableByType[fallbackType]!.first];
  }

  Future<void> _wait(double seconds) {
    if (seconds <= 0) {
      return Future.value();
    }
    final completer = Completer<void>();
    _pendingWaits.add(
      _DtWait(
        remaining: seconds,
        completer: completer,
      ),
    );
    return completer.future;
  }

  void _updateFailState() {
    final nextState = _slotTiles.length >= slotBar.slotCount && !board.isEmpty;
    if (nextState && !isGameOverNotifier.value && _saveData.streak != 0) {
      _saveData = _saveData.copyWith(streak: 0);
      _applySaveData();
      unawaited(saveGameRepository.save(_saveData));
    }
    isGameOverNotifier.value = nextState;
  }

  void _applySaveData() {
    progressNotifier.value = _saveData.completedLevels;
    streakNotifier.value = _saveData.streak;
    undoBoosterNotifier.value = _saveData.inventory.undo;
    shuffleBoosterNotifier.value = _saveData.inventory.shuffle;
    hintBoosterNotifier.value = _saveData.inventory.hint;
  }
}

class _MoveRecord {
  final TileComponent tile;
  final int row;
  final int column;

  const _MoveRecord({
    required this.tile,
    required this.row,
    required this.column,
  });
}

class _DtWait {
  double remaining;
  final Completer<void> completer;

  _DtWait({
    required this.remaining,
    required this.completer,
  });
}
