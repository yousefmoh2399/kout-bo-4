import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerStats {
  const PlayerStats({required this.games, required this.wins});
  final int games;
  final int wins;
}

class StatsRepository {
  StatsRepository(this._client);

  /// null عند عدم ضبط Supabase.
  final SupabaseClient? _client;

  Future<void> saveResult({
    required String? roomCode,
    required bool won,
    required int scoreUs,
    required int scoreThem,
    required int seconds,
    required int rounds,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    try {
      await c.from('game_results').insert({
        'user_id': uid,
        'room_code': roomCode,
        'won': won,
        'score_us': scoreUs,
        'score_them': scoreThem,
        'duration_seconds': seconds,
        'rounds': rounds,
      });
    } catch (_) {
      // حفظ الإحصائيات غير أساسي.
    }
  }

  Future<PlayerStats?> summary() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return null;
    try {
      final rows = await c.from('game_results').select('won').eq('user_id', uid);
      final list = List<Map<String, dynamic>>.from(rows as List);
      return PlayerStats(
        games: list.length,
        wins: list.where((r) => r['won'] == true).length,
      );
    } catch (_) {
      return null;
    }
  }
}
