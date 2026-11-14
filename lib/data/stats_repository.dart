import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerStats {
  const PlayerStats({
    required this.games,
    required this.wins,
    this.losses = 0,
    this.totalPoints = 0,
  });

  final int games;
  final int wins;
  final int losses;
  final int totalPoints;

  int get winRate => games == 0 ? 0 : ((wins / games) * 100).round();
}

class MatchHistoryItem {
  const MatchHistoryItem({
    required this.id,
    required this.roomCode,
    required this.gameMode,
    required this.won,
    required this.scoreUs,
    required this.scoreThem,
    required this.durationSeconds,
    required this.rounds,
    required this.createdAt,
  });

  final String id;
  final String roomCode;
  final String gameMode;
  final bool won;
  final int scoreUs;
  final int scoreThem;
  final int durationSeconds;
  final int rounds;
  final DateTime createdAt;

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      id: json['id']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? 'SOLO',
      gameMode: json['game_mode']?.toString() ?? 'solo',
      won: json['won'] == true,
      scoreUs: json['score_us'] as int? ?? 0,
      scoreThem: json['score_them'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      rounds: json['rounds'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LeaderboardItem {
  const LeaderboardItem({
    required this.userId,
    required this.name,
    required this.isGuest,
    required this.gamesPlayed,
    required this.wins,
    required this.winRate,
    required this.totalPoints,
  });

  final String userId;
  final String name;
  final bool isGuest;
  final int gamesPlayed;
  final int wins;
  final int winRate;
  final int totalPoints;

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'لاعب',
      isGuest: json['is_guest'] == true,
      gamesPlayed: json['games_played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.round() ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
    );
  }
}

class StatsRepository {
  StatsRepository(this._client);

  final SupabaseClient? _client;

  /// مزامنة بروفايل اللاعب مع جدول profiles في Supabase
  Future<void> syncProfile({required String name, bool isGuest = true}) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    try {
      await c.rpc('sync_profile', params: {
        'p_name': name,
        'p_is_guest': isGuest,
      });
    } catch (_) {
      try {
        await c.from('profiles').upsert({
          'id': uid,
          'name': name,
          'is_guest': isGuest,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  /// حفظ نتيجة كل مباراة (سواء سولو أو أونلاين) في قاعدة البيانات
  Future<void> saveResult({
    required String? roomCode,
    required bool won,
    required int scoreUs,
    required int scoreThem,
    required int seconds,
    required int rounds,
    String? playerName,
    List<Map<String, dynamic>>? roundLogs,
  }) async {
    // 1. التحديث المحلي السريع في ذاكرة الجهاز
    final prefs = await SharedPreferences.getInstance();
    final localGames = (prefs.getInt('local_games') ?? 0) + 1;
    final localWins = (prefs.getInt('local_wins') ?? 0) + (won ? 1 : 0);
    final localLosses = (prefs.getInt('local_losses') ?? 0) + (won ? 0 : 1);
    final localPoints = (prefs.getInt('local_points') ?? 0) + scoreUs;

    await prefs.setInt('local_games', localGames);
    await prefs.setInt('local_wins', localWins);
    await prefs.setInt('local_losses', localLosses);
    await prefs.setInt('local_points', localPoints);

    // 2. الحفظ المباشر في قاعدة بيانات Supabase
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;

    try {
      final name = playerName ?? prefs.getString('name') ?? 'لاعب';
      final mode = roomCode == null ? 'solo' : 'online';

      final res = await c.from('game_results').insert({
        'user_id': uid,
        'player_name': name,
        'room_code': roomCode ?? 'SOLO',
        'game_mode': mode,
        'won': won,
        'score_us': scoreUs,
        'score_them': scoreThem,
        'duration_seconds': seconds,
        'rounds': rounds,
      }).select('id').maybeSingle();

      // حفظ تفاصيل كل جولة إن وُجدت
      if (res != null && roundLogs != null && roundLogs.isNotEmpty) {
        final gameId = res['id'];
        final logsToInsert = roundLogs.map((log) => {
          ...log,
          'game_result_id': gameId,
          'user_id': uid,
          'room_code': roomCode ?? 'SOLO',
        }).toList();

        await c.from('game_round_logs').insert(logsToInsert);
      }
    } catch (_) {
      // تم الحفظ محلياً بالفعل وسيُحاول المزامنة لاحقاً
    }
  }

  /// جلب ملخص إحصائيات اللاعب من قاعدة البيانات مع كاش محلي
  Future<PlayerStats?> summary() async {
    final prefs = await SharedPreferences.getInstance();
    final localGames = prefs.getInt('local_games') ?? 0;
    final localWins = prefs.getInt('local_wins') ?? 0;
    final localLosses = prefs.getInt('local_losses') ?? 0;
    final localPoints = prefs.getInt('local_points') ?? 0;

    final c = _client;
    final uid = c?.auth.currentUser?.id;

    if (c == null || uid == null) {
      if (localGames > 0) {
        return PlayerStats(
          games: localGames,
          wins: localWins,
          losses: localLosses,
          totalPoints: localPoints,
        );
      }
      return null;
    }

    try {
      // محاولة الجلب من جدول profiles أولاً
      final profileRow = await c.from('profiles').select().eq('id', uid).maybeSingle();
      if (profileRow != null) {
        final g = profileRow['games_played'] as int? ?? 0;
        final w = profileRow['wins'] as int? ?? 0;
        final l = profileRow['losses'] as int? ?? 0;
        final p = profileRow['total_points'] as int? ?? 0;

        final maxGames = g > localGames ? g : localGames;
        final maxWins = w > localWins ? w : localWins;
        return PlayerStats(games: maxGames, wins: maxWins, losses: l, totalPoints: p);
      }

      // بديل: الاستعلام من game_results
      final rows = await c.from('game_results').select('won, score_us').eq('user_id', uid);
      final list = List<Map<String, dynamic>>.from(rows as List);
      final winsCount = list.where((r) => r['won'] == true).length;
      final pointsCount = list.fold<int>(0, (sum, r) => sum + (r['score_us'] as int? ?? 0));

      final finalGames = list.length > localGames ? list.length : localGames;
      final finalWins = winsCount > localWins ? winsCount : localWins;

      return PlayerStats(
        games: finalGames,
        wins: finalWins,
        losses: finalGames - finalWins,
        totalPoints: pointsCount,
      );
    } catch (_) {
      if (localGames > 0) {
        return PlayerStats(
          games: localGames,
          wins: localWins,
          losses: localLosses,
          totalPoints: localPoints,
        );
      }
      return null;
    }
  }

  /// جلب سجل آخر المباريات من قاعدة البيانات
  Future<List<MatchHistoryItem>> getMatchHistory({int limit = 20}) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return [];

    try {
      final rows = await c
          .from('game_results')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List).map((r) => MatchHistoryItem.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// جلب لوحة المتصدرين الحية من السيرفر
  Future<List<LeaderboardItem>> getLeaderboard({int limit = 50}) async {
    final c = _client;
    if (c == null) return [];

    try {
      // محاولة القراءة من فيو leaderboard
      final rows = await c
          .from('leaderboard')
          .select()
          .limit(limit);

      return (rows as List).map((r) => LeaderboardItem.fromJson(r)).toList();
    } catch (_) {
      try {
        // بديل: القراءة المباشرة من profiles
        final rows = await c
            .from('profiles')
            .select()
            .gt('games_played', 0)
            .order('wins', ascending: false)
            .limit(limit);

        return (rows as List).map((r) => LeaderboardItem.fromJson(r)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// تصفير الإحصائيات المحلية
  Future<void> clearLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_games');
    await prefs.remove('local_wins');
    await prefs.remove('local_losses');
    await prefs.remove('local_points');
  }
}
