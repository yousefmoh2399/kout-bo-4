import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Sfx { card, deal, bid, turn, tick, win, lose, trick, click }

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> haptics = ValueNotifier<bool>(true);
  final ValueNotifier<double> volume = ValueNotifier<double>(0.85);
  final ValueNotifier<bool> turnAlert = ValueNotifier<bool>(true);

  final List<AudioPlayer> _pool = [];
  final Map<Sfx, DateTime> _lastPlayed = {};
  final Map<Sfx, AssetSource> _sources = {
    for (final sfx in Sfx.values) sfx: AssetSource('sounds/${sfx.name}.wav'),
  };
  int _nextIdx = 0;
  bool _initialized = false;
  static const int _poolSize = 6;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool('sound_enabled') ?? true;
    haptics.value = prefs.getBool('haptics_enabled') ?? true;
    volume.value = prefs.getDouble('sound_volume') ?? 0.85;
    turnAlert.value = prefs.getBool('sound_turn_alert') ?? true;

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await _ensurePool();
      _initialized = true;
    } catch (_) {}
  }

  Future<AudioPlayer> _createPlayer() async {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.stop);
    try {
      // lowLatency (SoundPool على أندرويد) يمنع تقطيع الفريمات أثناء توزيع ولعب الورق
      await p.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      await p.setPlayerMode(PlayerMode.mediaPlayer);
    }
    return p;
  }

  Future<void> _ensurePool() async {
    if (_pool.isNotEmpty) return;
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(await _createPlayer());
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
  }

  Future<void> setHaptics(bool value) async {
    haptics.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics_enabled', value);
  }

  Future<void> setVolume(double value) async {
    volume.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', value);
  }

  Future<void> setTurnAlert(bool value) async {
    turnAlert.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_turn_alert', value);
  }

  void tap() {
    if (haptics.value) HapticFeedback.selectionClick();
  }

  void impact() {
    if (haptics.value) HapticFeedback.mediumImpact();
  }

  Future<void> play(Sfx sfx) async {
    if (!enabled.value) return;
    if (sfx == Sfx.turn && !turnAlert.value) return;

    final now = DateTime.now();
    final prev = _lastPlayed[sfx];
    if (prev != null && now.difference(prev).inMilliseconds < 35) return;
    _lastPlayed[sfx] = now;

    try {
      if (!_initialized) {
        await _ensurePool();
        _initialized = true;
      }
      if (_pool.isEmpty) return;

      var idx = _nextIdx;
      for (var i = 0; i < _pool.length; i++) {
        final candidate = (_nextIdx + i) % _pool.length;
        if (_pool[candidate].state != PlayerState.playing) {
          idx = candidate;
          break;
        }
      }
      _nextIdx = (idx + 1) % _pool.length;

      final source = _sources[sfx]!;
      final player = _pool[idx];
      try {
        await player.play(source, volume: volume.value);
      } catch (_) {
        // استبدال المشغل تلقائياً إذا تعطل لضمان عدم توقف الصوت أبداً.
        try {
          await player.dispose();
        } catch (_) {}
        final fresh = await _createPlayer();
        _pool[idx] = fresh;
        await fresh.play(source, volume: volume.value);
      }
    } catch (_) {}
  }
}
