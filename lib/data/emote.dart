/// رسالة دردشة سريعة (عبارة جاهزة) من لاعب.
class Emote {
  const Emote({required this.seat, required this.text});
  final int seat;
  final String text;
}

/// العبارات الجاهزة (لا نسمح بنص حر لتفادي الإساءة).
const List<String> kQuickPhrases = [
  '👏 أحسنت!',
  '😅 يا ساتر',
  '🤝 شريكي',
  '⏳ بسرعة',
  '😎 أنا الأقوى',
  '🙏 معلش',
];
