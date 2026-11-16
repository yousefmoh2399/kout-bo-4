/// مفاتيح Supabase تُمرَّر وقت التشغيل:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// بدونها تشتغل اللعبة محلياً ضد البوتات فقط.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xuptmbpeumjcksiehkcl.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1cHRtYnBldW1qY2tzaWVoa2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ2MTA4MDksImV4cCI6MjExMDE4NjgwOX0.H3torKKPVNgBwPevGfROXYR2-OH-CNHdR3STb8CT8Ik',
  );

  /// رابط سياسة الخصوصية (مطلوب لمتاجر التطبيقات).
  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );

  /// ───────────────────────────── بوابة ماي فاتورة (MyFatoorah) ─────────────────────────────
  /// مفتاح الربط (API Token): الصق المفتاح هنا أو مرره عبر --dart-define=MYFATOORAH_TOKEN=...
  static const myFatoorahToken = String.fromEnvironment(
    'MYFATOORAH_TOKEN',
    defaultValue: 'SK_KWT_NOSdOwOWhjRTTarvwG4ADkW7BqAGRw0j8BUiliADzdDVVAUFJZR7HH4nlKbQ3anl',
  );

  /// البيئة: false = تجريبي (Demo) | true = حقيقي (Live/Production)
  static const myFatoorahIsLive = bool.fromEnvironment(
    'MYFATOORAH_IS_LIVE',
    defaultValue: true,
  );

  /// العملة الرسمية للدفع في ماي فاتورة
  static const paymentCurrency = 'KWD';

  static bool get isMyFatoorahConfigured =>
      myFatoorahToken.isNotEmpty &&
      myFatoorahToken != 'YOUR_MYFATOORAH_API_TOKEN_HERE';

  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.2.0');

  static bool get isOnlineConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

enum BotDifficulty { normal, pro }

class GameSettings {
  const GameSettings({
    this.targetScore = 101,
    this.turnSeconds = 20,
    this.matchMinutes = 20,
    this.botDifficulty = BotDifficulty.normal,
    this.stakePoints = 0,
  });

  /// الهدف: 51 أو 101 نقطة.
  final int targetScore;

  /// مهلة الدور بالثواني (0 = بدون مؤقت).
  final int turnSeconds;

  /// مدة المباراة بالدقائق (0 = وقت مفتوح).
  final int matchMinutes;

  /// مستوى ذكاء البوتات.
  final BotDifficulty botDifficulty;

  /// رسم دخول الغرفة بالنقاط (0 = ودية مجانية).
  final int stakePoints;

  GameSettings copyWith({
    int? targetScore,
    int? turnSeconds,
    int? matchMinutes,
    BotDifficulty? botDifficulty,
    int? stakePoints,
  }) =>
      GameSettings(
        targetScore: targetScore ?? this.targetScore,
        turnSeconds: turnSeconds ?? this.turnSeconds,
        matchMinutes: matchMinutes ?? this.matchMinutes,
        botDifficulty: botDifficulty ?? this.botDifficulty,
        stakePoints: stakePoints ?? this.stakePoints,
      );
}
