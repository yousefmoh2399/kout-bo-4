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
  final Map<Sfx, AudioPlayer> _players = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool('sound_enabled') ?? true;
    haptics.value = prefs.getBool('haptics_enabled') ?? true;
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

  void tap() {
    if (haptics.value) HapticFeedback.selectionClick();
  }

  void impact() {
    if (haptics.value) HapticFeedback.mediumImpact();
  }

  Future<void> play(Sfx sfx) async {
    if (!enabled.value) return;
    try {
      final player = _players.putIfAbsent(sfx, () {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop);
        return p;
      });
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.name}.wav'), volume: 0.8);
    } catch (_) {
      // الصوت غير أساسي: نتجاهل أي خطأ.
    }
  }
}
