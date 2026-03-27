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
import 'package:tile_two/game/economy_service.dart';
import 'package:tile_two/game/fruit_sprite_sheet.dart';
import 'package:tile_two/game/game_analytics_service.dart';
import 'package:tile_two/game/item_randomization_service.dart';
import 'package:tile_two/game/level_manager.dart';
import 'package:tile_two/game/mission_service.dart';
import 'package:tile_two/game/save_game_repository.dart';
import 'package:tile_two/game/systems/gameplay_systems.dart';
import 'package:tile_two/game/tile_layout.dart';

class TileGame extends FlameGame {
  static const int minLevel = 1;
  static const int maxLevel = TileLayoutRules.maxLevel;
  final double footerReservedHeight;
  final int? initialLevel;
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> undoBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<int> shuffleBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<int> hintBoosterNotifier = ValueNotifier<int>(3);
  final ValueNotifier<bool> shuffleUnlockedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hintUnlockedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> coinNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> levelBannerNotifier =
      ValueNotifier<String>('Level 1');
  final ValueNotifier<double> matchFlashNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> isGameOverNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> onboardingRequiredNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<int> firstWinTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> levelWinTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> clearedLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> levelStartTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> smartHintTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> slotFullWarningTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> tapTileSfxTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<MatchSfxEvent?> matchSfxNotifier =
      ValueNotifier<MatchSfxEvent?>(null);
  final ValueNotifier<LevelItemDropEvent?> rareItemDropNotifier =
      ValueNotifier<LevelItemDropEvent?>(null);

  late final BoardComponent board;
  late final SlotBarComponent slotBar;
  late final LevelManager levelManager;
  late final FruitSpriteSheet fruitSpriteSheet;
  late final SaveGameRepository saveGameRepository;
  late SaveGameData _saveData;
  final ItemRandomizationService _itemRandomizationService =
      ItemRandomizationService.instance;
  final Map<String, int> _typeToSpriteIndex = {};

  final List<TileComponent> _slotTiles = [];
  final List<_MoveRecord> _history = [];
  final List<_DtWait> _pendingWaits = [];
  final math.Random _random = math.Random();
  final GameAnalyticsService _analytics = GameAnalyticsService.instance;
  final BoosterSystem _boosterSystem = BoosterSystem(
    economy: EconomyService.instance,
  );
  final ProgressionSystem _progressionSystem = ProgressionSystem(
    economy: EconomyService.instance,
    missionService: MissionService.instance,
  );
  bool _busy = false;
  bool _tapInFlight = false;
  bool _awaitingLevelContinue = false;
  bool _slotWarningArmed = false;
  bool _componentsReady = false;
  int? _pendingNextLevel;
  int? _pendingClearedLevel;
  int _comboCounter = 0;
  double _tileSize = 64;
  final double _spacing = 4;
  double _smartHintCooldown = 0;
  double _hintActionCooldown = 0;

  TileGame({
    required this.footerReservedHeight,
    this.initialLevel,
  });

  int get maxPlayableLevel => maxLevel;
  bool get isAwaitingLevelContinue => _awaitingLevelContinue;
  int get undoPrice => _boosterSystem.boosterPrice(BoosterType.undo);
  int get shufflePrice => _boosterSystem.boosterPrice(BoosterType.shuffle);
  int get hintPrice => _boosterSystem.boosterPrice(BoosterType.hint);
  int get shuffleUnlockLevel => _boosterSystem.shuffleUnlockLevel;
  int get hintUnlockLevel => _boosterSystem.hintUnlockLevel;

  int boosterUnlockLevel(BoosterType type) {
    return _boosterSystem.unlockLevelFor(type);
  }

  bool isBoosterUnlocked(BoosterType type) {
    return _isBoosterUnlocked(type);
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _analytics.trackSessionStart();
    images.prefix = 'assets/images/';
    fruitSpriteSheet = await FruitSpriteSheet.load(images: images);

    camera.viewport = MaxViewport();

    levelManager = const LevelManager();
    saveGameRepository = SaveGameRepository();
    _saveData = await saveGameRepository.load();
    _saveData = MissionService.instance.normalize(saveData: _saveData);
    if (initialLevel != null) {
      _saveData = _saveData.copyWith(
        currentLevel: initialLevel!.clamp(minLevel, maxLevel),
      );
    }
    _applySaveData();
    onboardingRequiredNotifier.value = !_saveData.onboardingCompleted;
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
    _syncSlotWarningState();
    if (_smartHintCooldown > 0) {
      _smartHintCooldown = (_smartHintCooldown - dt).clamp(0, 60).toDouble();
    }
    if (_hintActionCooldown > 0) {
      _hintActionCooldown = (_hintActionCooldown - dt).clamp(0, 60).toDouble();
    }
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
      isGameOverNotifier.value = false;
      _awaitingLevelContinue = false;
      _slotWarningArmed = false;
      _smartHintCooldown = 0;
      _hintActionCooldown = 0;
      _pendingNextLevel = null;
      _pendingClearedLevel = null;
      final safeLevel = level.clamp(minLevel, maxLevel);
      levelNotifier.value = safeLevel;
      levelBannerNotifier.value = 'Level $safeLevel';
      _analytics.trackLevelStart(level: safeLevel);
      _saveData = _saveData.copyWith(currentLevel: safeLevel);
      await saveGameRepository.save(_saveData);
      final desiredTypeCount = TileLayoutRules.configForLevel(safeLevel).tileTypes;
      final itemDrop = await _itemRandomizationService.pickForLevel(
        level: safeLevel,
        requestedPoolSize: desiredTypeCount,
      );
      _typeToSpriteIndex
        ..clear()
        ..addEntries(
          itemDrop.levelPool.map(
            (entry) => MapEntry(entry.id, entry.spriteIndex),
          ),
        );
      if (itemDrop.rarity != ItemRarity.common) {
        rareItemDropNotifier.value = LevelItemDropEvent(
          itemId: itemDrop.featuredItem.id,
          rarity: itemDrop.rarity,
          spriteIndex: itemDrop.featuredItem.spriteIndex,
          level: safeLevel,
        );
      } else {
        rareItemDropNotifier.value = null;
      }
      final layout = levelManager.build(
        level: safeLevel,
        columns: board.columns,
        rows: board.rows,
        tileTypes: itemDrop.levelPool.map((entry) => entry.id).toList(),
      );
      await board.loadLayout(layout);
      levelStartTriggerNotifier.value = levelStartTriggerNotifier.value + 1;
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
    const slotTopY = 64.0;
    slotBar.updateLayout(
      topLeft: Vector2(
        (canvasSize.x -
                ((slotBar.slotCount * slotSize) +
                    ((slotBar.slotCount - 1) * _spacing))) /
            2,
        slotTopY,
      ),
      newSlotSize: slotSize,
      newSpacing: _spacing,
    );

    final boardWidth =
        (board.columns * _tileSize) + ((board.columns - 1) * _spacing);
    final boardHeight =
        (board.rows * _tileSize) + ((board.rows - 1) * _spacing);
    final playAreaTop = slotBar.position.y + slotSize + 24;
    final playAreaBottom = canvasSize.y - footerReservedHeight - 20;
    final maxTop = (playAreaBottom - boardHeight)
        .clamp(playAreaTop, canvasSize.y)
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
    if (_busy ||
        _tapInFlight ||
        _awaitingLevelContinue ||
        isGameOverNotifier.value ||
        _slotTiles.length >= slotBar.slotCount) {
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
    tapTileSfxTriggerNotifier.value = tapTileSfxTriggerNotifier.value + 1;

    try {
      tile
        ..isInTransit = true
        ..setTapEnabled(false)
        ..position = worldTopLeft
        ..priority = 3000;
      tile.prepareForSlotVisual();
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
      tile.add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.18),
            EffectController(duration: 0.08, curve: Curves.easeOut),
          ),
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(duration: 0.17, curve: Curves.easeIn),
          ),
        ]),
      );
      tile.add(
        SequenceEffect([
          RotateEffect.to(
            (_slotTiles.length % 2 == 0 ? 1 : -1) * 0.08,
            EffectController(duration: 0.12, curve: Curves.easeOut),
          ),
          RotateEffect.to(
            0,
            EffectController(duration: 0.13, curve: Curves.easeIn),
          ),
        ]),
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

        final matched =
            _slotTiles.where((tile) => tile.type == type).take(3).toList();
        _comboCounter += 1;
        matchSfxNotifier.value = MatchSfxEvent(combo: _comboCounter);
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
    final isFirstWin = !_saveData.firstWinClaimed;
    if (isFirstWin) {
      _saveData = _saveData.copyWith(firstWinClaimed: true);
    }
    _analytics.trackLevelClear(
      level: levelNotifier.value,
      streak: _saveData.streak + 1,
    );
    levelBannerNotifier.value = 'Level ${levelNotifier.value} Complete';
    await _wait(0.7);
    for (final tile in _slotTiles) {
      tile.removeFromParent();
    }
    _slotTiles.clear();
    final nextLevel = _progressionSystem.nextLevel(
      currentLevel: levelNotifier.value,
      maxLevel: maxLevel,
    );
    _pendingClearedLevel = levelNotifier.value;
    _pendingNextLevel = nextLevel;
    _awaitingLevelContinue = true;
    clearedLevelNotifier.value = levelNotifier.value;
    
    if (isFirstWin) {
      firstWinTriggerNotifier.value = firstWinTriggerNotifier.value + 1;
    } else {
      levelWinTriggerNotifier.value = levelWinTriggerNotifier.value + 1;
    }
    _busy = false;
  }

  Future<void> continueAfterLevelWin() async {
    if (_busy || !_awaitingLevelContinue) {
      return;
    }
    _busy = true;
    final clearedLevel = _pendingClearedLevel ?? levelNotifier.value;
    final nextLevel = _pendingNextLevel ?? levelNotifier.value;
    _awaitingLevelContinue = false;
    _pendingClearedLevel = null;
    _pendingNextLevel = null;
    _saveData = _progressionSystem.applyLevelClear(
      saveData: _saveData,
      clearedLevel: clearedLevel,
      nextLevel: nextLevel,
    );
    _applySaveData();
    await saveGameRepository.save(_saveData);
    await _loadLevel(nextLevel);
    _busy = false;
  }

  Future<bool> reviveFromGameOver() async {
    if (_busy ||
        _tapInFlight ||
        !isGameOverNotifier.value ||
        _slotTiles.isEmpty) {
      return false;
    }
    _busy = true;
    final removeCount = _slotTiles.length >= 3 ? 3 : 1;
    final toRestore = <TileComponent>[];

    for (var i = 0; i < removeCount; i++) {
      if (_slotTiles.isEmpty) {
        break;
      }
      final tile = _slotTiles.removeLast();
      toRestore.add(tile);
    }
    await _shiftSlotTilesLeft();

    for (final tile in toRestore) {
      final recordIndex =
          _history.lastIndexWhere((record) => identical(record.tile, tile));
      if (recordIndex >= 0) {
        final record = _history.removeAt(recordIndex);
        final target = board.worldPositionForRestore(
          row: record.row,
          column: record.column,
        );
        tile.isInTransit = true;
        tile.setTapEnabled(false);
        tile.add(
          MoveEffect.to(
            target,
            EffectController(duration: 0.25, curve: Curves.easeOut),
          ),
        );
        board.restoreTile(
          tile: record.tile,
          row: record.row,
          column: record.column,
        );
      } else {
        tile.removeFromParent();
      }
    }
    await _wait(0.25);
    for (final tile in toRestore) {
      tile.isInTransit = false;
    }

    _updateFailState();
    _busy = false;
    return !isGameOverNotifier.value;
  }

  Future<void> grantBonusHint({int amount = 1}) async {
    if (amount <= 0) {
      return;
    }
    _saveData = _saveData.copyWith(
      inventory: _saveData.inventory.copyWith(
        hint: _saveData.inventory.hint + amount,
      ),
    );
    _applySaveData();
    await saveGameRepository.save(_saveData);
  }

  Future<void> shuffleBoard() async {
    if (_busy ||
        _tapInFlight ||
        _awaitingLevelContinue ||
        isGameOverNotifier.value) {
      return;
    }
    if (!_canUseBooster(BoosterType.shuffle)) {
      return;
    }
    _busy = true;
    final shuffled = await board.shuffleRemainingTiles();
    _busy = false;
    if (shuffled && _consumeBoosterOrCoins(BoosterType.shuffle)) {
      _saveData =
          MissionService.instance.recordShuffleUsed(saveData: _saveData);
      _applySaveData();
      await saveGameRepository.save(_saveData);
    }
    _updateFailState();
  }

  Future<void> provideHint() async {
    if (_busy ||
        _tapInFlight ||
        _awaitingLevelContinue ||
        isGameOverNotifier.value ||
        _hintActionCooldown > 0) {
      return;
    }
    if (!_canUseBooster(BoosterType.hint)) {
      return;
    }
    final freeSlots = (slotBar.slotCount - _slotTiles.length).clamp(0, slotBar.slotCount);
    if (freeSlots <= 0) {
      return;
    }
    final autoTargets = _bestAutoFillHintTiles(freeSlots: freeSlots);
    if (autoTargets.isEmpty) {
      final hint = _bestHintTiles();
      if (hint.isEmpty) {
        return;
      }
      board.highlightTiles(hint, seconds: 1.1);
      smartHintTriggerNotifier.value = smartHintTriggerNotifier.value + 1;
      if (_consumeBoosterOrCoins(BoosterType.hint)) {
        _saveData = MissionService.instance.recordHintUsed(saveData: _saveData);
        _applySaveData();
        unawaited(saveGameRepository.save(_saveData));
      }
      _hintActionCooldown = 2.8;
      return;
    }
    board.highlightTiles(autoTargets, seconds: 1.15);
    var movedCount = 0;
    for (final tile in autoTargets) {
      if (_slotTiles.length >= slotBar.slotCount || _busy || _tapInFlight) {
        break;
      }
      await _handleBoardTap(tile);
      movedCount++;
    }
    if (movedCount <= 0) {
      return;
    }
    smartHintTriggerNotifier.value = smartHintTriggerNotifier.value + 1;
    if (_consumeBoosterOrCoins(BoosterType.hint)) {
      _saveData = MissionService.instance.recordHintUsed(saveData: _saveData);
      _applySaveData();
      await saveGameRepository.save(_saveData);
    }
    _hintActionCooldown = 4.4;
  }

  List<TileComponent> _bestAutoFillHintTiles({required int freeSlots}) {
    if (freeSlots <= 0) {
      return const [];
    }
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
    String? targetType;
    var bestScore = -1;
    var bestTakeCount = 0;
    for (final entry in slotTypeCount.entries) {
      final slotCount = entry.value;
      if (slotCount <= 0 || slotCount >= 3) {
        continue;
      }
      final candidates = playableByType[entry.key];
      if (candidates == null || candidates.isEmpty) {
        continue;
      }
      final needed = (3 - slotCount).clamp(1, 2);
      final takeCount = needed.clamp(1, freeSlots);
      if (takeCount > candidates.length) {
        continue;
      }
      final score = (slotCount * 10) + takeCount;
      if (score > bestScore) {
        bestScore = score;
        targetType = entry.key;
        bestTakeCount = takeCount;
      }
    }
    if (targetType == null || bestTakeCount <= 0) {
      return const [];
    }
    return playableByType[targetType]!.take(bestTakeCount).toList();
  }

  Future<void> undoLastMove() async {
    if (_busy ||
        _tapInFlight ||
        _awaitingLevelContinue ||
        _history.isEmpty ||
        _slotTiles.isEmpty) {
      return;
    }
    if (!_canUseBooster(BoosterType.undo)) {
      return;
    }
    final recordIndex =
        _history.lastIndexWhere((record) => _slotTiles.contains(record.tile));
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
    if (_consumeBoosterOrCoins(BoosterType.undo)) {
      _applySaveData();
      await saveGameRepository.save(_saveData);
    }
    _updateFailState();
    _busy = false;
  }

  Future<void> retryCurrentLevel() async {
    if (_busy || _tapInFlight || _awaitingLevelContinue) {
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

  Future<void> completeOnboarding() async {
    if (_saveData.onboardingCompleted) {
      onboardingRequiredNotifier.value = false;
      return;
    }
    _saveData = _saveData.copyWith(onboardingCompleted: true);
    onboardingRequiredNotifier.value = false;
    await saveGameRepository.save(_saveData);
  }

  Future<void> selectLevel(int level) async {
    if (_busy || _tapInFlight || _awaitingLevelContinue) {
      return;
    }
    _busy = true;
    for (final tile in _slotTiles) {
      tile.removeFromParent();
    }
    _slotTiles.clear();
    _history.clear();
    isGameOverNotifier.value = false;
    await _loadLevel(level);
    _busy = false;
  }

  void _spawnMatchBurst(Vector2 center) {
    final colors = [
      const Color(0xFFFFE082),
      const Color(0xFFFFF59D),
      const Color(0xFFFFCC80),
      const Color(0xFFFFFFFF),
    ];
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 35,
          lifespan: 0.55,
          generator: (index) {
            final isHighlight = index % 5 == 0;
            final angle = _random.nextDouble() * math.pi * 2;
            final speed = 80 + _random.nextDouble() * (isHighlight ? 160 : 70);
            return AcceleratedParticle(
              acceleration: Vector2(0, 190),
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              position: center.clone(),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final progress = particle.progress;
                  final scale = 1.0 - (progress * progress);
                  final paint = Paint()
                    ..color = colors[index % colors.length]
                        .withValues(alpha: 1.0 - progress)
                    ..maskFilter = isHighlight 
                        ? const MaskFilter.blur(BlurStyle.normal, 2.5) 
                        : null;
                  canvas.drawCircle(
                    Offset.zero,
                    (isHighlight ? 3.5 : 2.0) * scale,
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
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
          (need == bestNeed &&
              slotCount == bestSlotCount &&
              playableCount > bestPlayableCount);
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
    final fallbackType = playableByType.entries
        .reduce((a, b) => a.value.length >= b.value.length ? a : b)
        .key;
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
    if (!nextState) {
      _maybeTriggerSmartHint();
    }
    if (nextState && !isGameOverNotifier.value) {
      _analytics.trackLevelFail(
        level: levelNotifier.value,
        slotUsed: _slotTiles.length,
        slotCapacity: slotBar.slotCount,
      );
    }
    if (nextState && !isGameOverNotifier.value && _saveData.streak != 0) {
      _saveData = _progressionSystem.resetStreakOnFail(saveData: _saveData);
      _applySaveData();
      unawaited(saveGameRepository.save(_saveData));
    }
    isGameOverNotifier.value = nextState;
    _syncSlotWarningState();
  }

  void _syncSlotWarningState() {
    if (!_componentsReady) {
      return;
    }
    final shouldWarn =
        !isGameOverNotifier.value && _slotTiles.length >= slotBar.slotCount - 2;
    slotBar.setWarningActive(shouldWarn);
    if (shouldWarn && !_slotWarningArmed) {
      _slotWarningArmed = true;
      slotFullWarningTriggerNotifier.value =
          slotFullWarningTriggerNotifier.value + 1;
    } else if (!shouldWarn) {
      _slotWarningArmed = false;
    }
  }




  void _maybeTriggerSmartHint({bool force = false}) {
    final inRiskWindow = _slotTiles.length >= slotBar.slotCount - 2;
    if (!force && (!inRiskWindow || _smartHintCooldown > 0)) {
      return;
    }
    if (_busy || _tapInFlight || _awaitingLevelContinue || isGameOverNotifier.value) {
      return;
    }
    final hint = _bestHintTiles();
    if (hint.isEmpty) {
      return;
    }
    board.highlightTiles(hint, seconds: force ? 1.4 : 1);
    smartHintTriggerNotifier.value = smartHintTriggerNotifier.value + 1;
    _smartHintCooldown = force ? 4.5 : 6.5;
  }

  void _applySaveData() {
    progressNotifier.value = _saveData.completedLevels;
    streakNotifier.value = _saveData.streak;
    undoBoosterNotifier.value = _saveData.inventory.undo;
    shuffleBoosterNotifier.value = _saveData.inventory.shuffle;
    hintBoosterNotifier.value = _saveData.inventory.hint;
    coinNotifier.value = _saveData.coins;
    shuffleUnlockedNotifier.value = _isBoosterUnlocked(BoosterType.shuffle);
    hintUnlockedNotifier.value = _isBoosterUnlocked(BoosterType.hint);
  }

  bool _canUseBooster(BoosterType type) {
    return _boosterSystem.canUse(type: type, saveData: _saveData);
  }

  bool _isBoosterUnlocked(BoosterType type) {
    return _boosterSystem.isUnlocked(type: type, saveData: _saveData);
  }

  bool _consumeBoosterOrCoins(BoosterType type) {
    final updated = _boosterSystem.consumeUseCost(
      type: type,
      saveData: _saveData,
    );
    if (updated == null) {
      return false;
    }
    _saveData = updated;
    return true;
  }

  Future<bool> buyBooster(BoosterType type, {int amount = 1}) async {
    final updated = _boosterSystem.buy(
      type: type,
      amount: amount,
      saveData: _saveData,
    );
    if (updated == null) {
      return false;
    }
    _saveData = updated;
    _applySaveData();
    await saveGameRepository.save(_saveData);
    return true;
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

class MatchSfxEvent {
  final int combo;

  const MatchSfxEvent({
    required this.combo,
  });
}

class LevelItemDropEvent {
  final String itemId;
  final ItemRarity rarity;
  final int spriteIndex;
  final int level;

  const LevelItemDropEvent({
    required this.itemId,
    required this.rarity,
    required this.spriteIndex,
    required this.level,
  });
}
