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
  int _nextIdx = 0;
  bool _initialized = false;

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
      _ensurePool();
      _initialized = true;
    } catch (_) {}
  }

  void _ensurePool() {
    if (_pool.isNotEmpty) return;
    for (var i = 0; i < 3; i++) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      p.setPlayerMode(PlayerMode.lowLatency);
      _pool.add(p);
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
    try {
      if (!_initialized) _ensurePool();
      if (_pool.isEmpty) return;
      final player = _pool[_nextIdx % _pool.length];
      _nextIdx = (_nextIdx + 1) % _pool.length;
      await player.setVolume(volume.value);
      await player.play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (_) {}
  }
}
