import 'package:flutter/widgets.dart';

import '../domain/deck.dart';

/// خدمة التحميل المسبق (Pre-caching) لصور الكروت الملكية في ذاكرة المعالج الرسومي (GPU Texture Cache)
/// لضمان أعلى سلاسة ممكنة (60/120 إطار بالثانية) أثناء حركة وتوزيع ورمي البطاقات بدون أي تقطيع.
class CardImageService {
  CardImageService._();

  static bool _precached = false;

  static const String cardBackAsset = 'assets/cards/card_back.png';

  static List<String> get allCardAssets {
    final list = <String>[];
    for (final card in Deck.build()) {
      list.add(card.assetPath);
    }
    list.add(cardBackAsset);
    return list;
  }

  /// تحميل جميع صور الكروت في الـ ImageCache مسبقاً
  static Future<void> precacheDeck(BuildContext context) async {
    if (_precached) return;
    _precached = true;
    for (final assetPath in allCardAssets) {
      try {
        await precacheImage(AssetImage(assetPath), context);
      } catch (_) {
        // الاستمرار بدون إيقاف التطبيق في حال عدم توفر الصورة في بيئة الاختبارات
      }
    }
  }
}
