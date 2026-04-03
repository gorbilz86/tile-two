import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameAudioService {
  GameAudioService._();

  static final GameAudioService instance = GameAudioService._();

  static const String _musicEnabledKey = 'music_enabled';
  static const String _homeTrack = 'home';
  static const String _gameTrack = 'game';
  static const String _matchCue = 'match_cue';
  static const String _tapTileCue = 'tap_tile_cue';
  static const String _levelCompleteCue = 'level_complete_cue';
  static const String _gameStartCue = 'game_start_cue';
  static const String _slotWarningCue = 'slot_warning_cue';
  static const String _gameOverCue = 'game_over_cue';
  static const List<String> _homeTrackCandidates = [
    'home_theme.mp3',
    'bgm/home_loop.mp3',
  ];
  static const List<String> _gameTrackCandidates = [
    'game_theme.mp3',
    'bgm/game_loop.mp3',
  ];
  static const List<String> _matchCueCandidates = [
    'match_triple.mp3',
    'match_3.mp3',
    'sfx/match_3.mp3',
  ];
  static const List<String> _tapTileCueCandidates = [
    'tap_tile.mp3',
    'sfx/tap_tile.mp3',
  ];
  static const List<String> _levelCompleteCueCandidates = [
    'level_complete.mp3',
    'sfx/level_complete.mp3',
  ];
  static const List<String> _gameStartCueCandidates = [
    'game_start.mp3',
    'sfx/game_start.mp3',
  ];
  static const List<String> _slotWarningCueCandidates = [
    'slot_warning.mp3',
    'sfx/slot_warning.mp3',
  ];
  static const List<String> _gameOverCueCandidates = [
    'game_over.mp3',
    'sfx/game_over.mp3',
  ];

  bool _initialized = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  String? _activeTrackKey;
  final Map<String, String> _resolvedTrackByKey = {};
  final Map<String, AudioPool> _pools = {};

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;

  static const String _sfxEnabledKey = 'sfx_enabled';

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
      _sfxEnabled = prefs.getBool(_sfxEnabledKey) ?? true;

      FlameAudio.bgm.initialize();

      // Clear existing pools to prevent leaks on re-init
      for (final pool in _pools.values) {
        unawaited(pool.dispose());
      }
      _pools.clear();

      await _resolveTrack(
        key: _homeTrack,
        candidates: _homeTrackCandidates,
      );
      await _resolveTrack(
        key: _gameTrack,
        candidates: _gameTrackCandidates,
      );
      await _resolveTrack(
        key: _matchCue,
        candidates: _matchCueCandidates,
      );
      await _resolveTrack(
        key: _tapTileCue,
        candidates: _tapTileCueCandidates,
      );

      // Pre-initialize pools for frequent sounds
      if (_resolvedTrackByKey.containsKey(_tapTileCue)) {
        _pools[_tapTileCue] = await FlameAudio.createPool(
          _resolvedTrackByKey[_tapTileCue]!,
          minPlayers: 1,
          maxPlayers: 5,
        );
      }
      if (_resolvedTrackByKey.containsKey(_matchCue)) {
        _pools[_matchCue] = await FlameAudio.createPool(
          _resolvedTrackByKey[_matchCue]!,
          minPlayers: 1,
          maxPlayers: 3,
        );
      }

      await _resolveTrack(
        key: _levelCompleteCue,
        candidates: _levelCompleteCueCandidates,
      );
      await _resolveTrack(
        key: _gameStartCue,
        candidates: _gameStartCueCandidates,
      );
      await _resolveTrack(
        key: _slotWarningCue,
        candidates: _slotWarningCueCandidates,
      );
      await _resolveTrack(
        key: _gameOverCue,
        candidates: _gameOverCueCandidates,
      );
      _initialized = true;
    } catch (error) {
      debugPrint('[audio] init failed: $error');
      _initialized = false;
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);
    if (!_musicEnabled) {
      FlameAudio.bgm.stop();
      return;
    }
    if (_activeTrackKey != null) {
      await _playLoop(_activeTrackKey!);
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxEnabledKey, enabled);
  }

  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    _pools.clear();
    FlameAudio.bgm.stop();
    _initialized = false;
  }

  Future<void> playHomeLoop() async {
    await _playLoop(_homeTrack);
  }

  Future<void> playGameLoop() async {
    _activeTrackKey = null;
    FlameAudio.bgm.stop();
  }

  void stopBgm() {
    FlameAudio.bgm.stop();
  }

  Future<void> playRareItemCue() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  Future<void> playMatchCue({int combo = 1}) async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }

    final pool = _pools[_matchCue];
    final volume =
        (0.44 + ((combo.clamp(1, 5) - 1) * 0.05)).clamp(0.44, 0.64).toDouble();

    if (pool != null) {
      pool.start(volume: volume);
      return;
    }

    final resolvedCue = _resolvedTrackByKey[_matchCue];
    if (resolvedCue == null) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      return;
    }
    try {
      await FlameAudio.play(resolvedCue, volume: volume);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  Future<void> playTapTileCue() async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }

    final pool = _pools[_tapTileCue];
    if (pool != null) {
      pool.start(volume: 0.34);
      return;
    }

    final resolvedCue = _resolvedTrackByKey[_tapTileCue];
    if (resolvedCue == null) {
      return;
    }
    try {
      await FlameAudio.play(resolvedCue, volume: 0.34);
    } catch (_) {}
  }

  Future<void> playLevelCompleteCue() async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }
    var resolvedCue = _resolvedTrackByKey[_levelCompleteCue];
    if (resolvedCue == null) {
      await _resolveTrack(
        key: _levelCompleteCue,
        candidates: _levelCompleteCueCandidates,
      );
      resolvedCue = _resolvedTrackByKey[_levelCompleteCue];
    }
    if (resolvedCue == null) {
      return;
    }
    try {
      await FlameAudio.play(resolvedCue, volume: 0.52);
    } catch (_) {}
  }

  Future<void> playGameStartCue() async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }
    var resolvedCue = _resolvedTrackByKey[_gameStartCue];
    if (resolvedCue == null) {
      await _resolveTrack(
        key: _gameStartCue,
        candidates: _gameStartCueCandidates,
      );
      resolvedCue = _resolvedTrackByKey[_gameStartCue];
    }
    if (resolvedCue == null) {
      return;
    }
    try {
      await FlameAudio.play(resolvedCue, volume: 0.48);
    } catch (_) {}
  }

  Future<void> playSlotWarningCue() async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }
    final resolvedCue = _resolvedTrackByKey[_slotWarningCue];
    if (resolvedCue != null) {
      try {
        await FlameAudio.play(resolvedCue, volume: 0.56);
        return;
      } catch (_) {}
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  Future<void> playGameOverCue() async {
    if (!_sfxEnabled) return;
    if (!_initialized) {
      unawaited(init());
    }
    final resolvedCue = _resolvedTrackByKey[_gameOverCue];
    if (resolvedCue == null) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      return;
    }
    try {
      await FlameAudio.play(resolvedCue, volume: 0.6);
    } catch (_) {}
  }

  Future<void> _playLoop(String track) async {
    if (!_initialized) {
      await init();
    }
    _activeTrackKey = track;
    if (!_musicEnabled || !_initialized) {
      return;
    }
    final resolvedTrack = _resolvedTrackByKey[track];
    if (resolvedTrack == null) {
      debugPrint('[audio] track not resolved for key: $track');
      return;
    }
    try {
      FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(resolvedTrack, volume: 0.62);
    } catch (error) {
      debugPrint('[audio] play failed: $error');
    }
  }

  Future<void> _resolveTrack({
    required String key,
    required List<String> candidates,
  }) async {
    for (final candidate in candidates) {
      try {
        await FlameAudio.audioCache.load(candidate);
        _resolvedTrackByKey[key] = candidate;
        debugPrint('[audio] resolved $key => $candidate');
        return;
      } catch (_) {}
    }
    debugPrint('[audio] unable to resolve track for key: $key');
  }
}
