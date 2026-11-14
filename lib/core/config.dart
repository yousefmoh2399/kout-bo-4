/// مفاتيح Supabase تُمرَّر وقت التشغيل:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// بدونها تشتغل اللعبة محلياً ضد البوتات فقط.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// رابط سياسة الخصوصية (مطلوب لمتاجر التطبيقات).
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');

  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.2.0');

  static bool get isOnlineConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

enum BotDifficulty { normal, pro }

class GameSettings {
  const GameSettings({
    this.targetScore = 101,
    this.turnSeconds = 20,
    this.matchMinutes = 0,
    this.botDifficulty = BotDifficulty.normal,
  });

  /// الهدف: 51 أو 101 نقطة.
  final int targetScore;

  /// مهلة الدور بالثواني (0 = بدون مؤقت).
  final int turnSeconds;

  /// مدة المباراة بالدقائق (0 = وقت مفتوح).
  final int matchMinutes;

  /// مستوى ذكاء البوتات.
  final BotDifficulty botDifficulty;

  GameSettings copyWith({
    int? targetScore,
    int? turnSeconds,
    int? matchMinutes,
    BotDifficulty? botDifficulty,
  }) =>
      GameSettings(
        targetScore: targetScore ?? this.targetScore,
        turnSeconds: turnSeconds ?? this.turnSeconds,
        matchMinutes: matchMinutes ?? this.matchMinutes,
        botDifficulty: botDifficulty ?? this.botDifficulty,
      );
}
