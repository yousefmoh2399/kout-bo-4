import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/card.dart';

/// مسارات متجهة نقية وفائقة الدقة لرموز الورق الأربعة (♠, ♥, ♦, ♣).
/// تعمل 100% بدون أي اعتماد على خطوط النظام وتضمن مظهر متطابق وفاخر على الآيفون والآندرويد.
class SuitPath {
  SuitPath._();

  /// إنشاء مسار الرمز بقياس محدد.
  static Path getPath(Suit suit, Size size) {
    switch (suit) {
      case Suit.spades:
        return _spadesPath(size);
      case Suit.hearts:
        return _heartsPath(size);
      case Suit.diamonds:
        return _diamondsPath(size);
      case Suit.clubs:
        return _clubsPath(size);
    }
  }

  /// قلب متناسق وناعم (♥).
  static Path _heartsPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // نقطة الانقسام العلوية في المنتصف
    path.moveTo(w * 0.50, h * 0.28);

    // القوس الأيسر
    path.cubicTo(w * 0.44, h * 0.06, w * 0.04, h * 0.06, w * 0.03, h * 0.38);
    path.cubicTo(w * 0.02, h * 0.62, w * 0.26, h * 0.79, w * 0.50, h * 0.98);

    // القوس الأيمن
    path.cubicTo(w * 0.74, h * 0.79, w * 0.98, h * 0.62, w * 0.97, h * 0.38);
    path.cubicTo(w * 0.96, h * 0.06, w * 0.56, h * 0.06, w * 0.50, h * 0.28);

    path.close();
    return path;
  }

  /// ديمن / ماسة هندسية دقيقة وأنيقة (♦).
  static Path _diamondsPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    path.moveTo(w * 0.50, h * 0.02);
    // حواف رشيقة مع انحناء خفيف جداً يمنحها رونق أوراق اللعب الملكية
    path.cubicTo(w * 0.53, h * 0.24, w * 0.76, h * 0.47, w * 0.97, h * 0.50);
    path.cubicTo(w * 0.76, h * 0.53, w * 0.53, h * 0.76, w * 0.50, h * 0.98);
    path.cubicTo(w * 0.47, h * 0.76, w * 0.24, h * 0.53, w * 0.03, h * 0.50);
    path.cubicTo(w * 0.24, h * 0.47, w * 0.47, h * 0.24, w * 0.50, h * 0.02);

    path.close();
    return path;
  }

  /// سبيت / رأس حربة متقن مع قاعدة انسيابية (♠).
  static Path _spadesPath(Size size) {
    final w = size.width;
    final h = size.height;

    // جسم السبيت (قلب مقلوب حاد الرأس)
    final body = Path()
      ..moveTo(w * 0.50, h * 0.02)
      ..cubicTo(w * 0.56, h * 0.20, w * 0.98, h * 0.36, w * 0.98, h * 0.60)
      ..cubicTo(w * 0.98, h * 0.78, w * 0.74, h * 0.84, w * 0.50, h * 0.72)
      ..cubicTo(w * 0.26, h * 0.84, w * 0.02, h * 0.78, w * 0.02, h * 0.60)
      ..cubicTo(w * 0.02, h * 0.36, w * 0.44, h * 0.20, w * 0.50, h * 0.02)
      ..close();

    // ساق القاعدة
    final stem = Path()
      ..moveTo(w * 0.46, h * 0.60)
      ..cubicTo(w * 0.46, h * 0.78, w * 0.34, h * 0.93, w * 0.27, h * 0.98)
      ..lineTo(w * 0.73, h * 0.98)
      ..cubicTo(w * 0.66, h * 0.93, w * 0.54, h * 0.78, w * 0.54, h * 0.60)
      ..close();

    return Path.combine(PathOperation.union, body, stem);
  }

  /// شيريا / زهرة ثلاثية متناسقة مع ساق كلاسيكية (♣).
  static Path _clubsPath(Size size) {
    final w = size.width;
    final h = size.height;

    // الفصوص الثلاثة الدائرية مع قرص مركزي
    final r = w * 0.235;
    final lobes = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.50, h * 0.27), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(w * 0.275, h * 0.54), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(w * 0.725, h * 0.54), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(w * 0.50, h * 0.48), radius: w * 0.20));

    // الساق العريضة في الأسفل
    final stem = Path()
      ..moveTo(w * 0.46, h * 0.45)
      ..cubicTo(w * 0.46, h * 0.76, w * 0.33, h * 0.93, w * 0.26, h * 0.98)
      ..lineTo(w * 0.74, h * 0.98)
      ..cubicTo(w * 0.67, h * 0.93, w * 0.54, h * 0.76, w * 0.54, h * 0.45)
      ..close();

    return Path.combine(PathOperation.union, lobes, stem);
  }
}

/// رسام الرمز على الـ Canvas مباشرة مع دعم الظلال الناعمة.
class SuitPainter extends CustomPainter {
  const SuitPainter({
    required this.suit,
    required this.color,
    this.shadows,
  });

  final Suit suit;
  final Color color;
  final List<Shadow>? shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = SuitPath.getPath(suit, size);

    if (shadows != null && shadows!.isNotEmpty) {
      for (final s in shadows!) {
        final shadowPaint = s.toPaint();
        canvas.save();
        canvas.translate(s.offset.dx, s.offset.dy);
        canvas.drawPath(path, shadowPaint);
        canvas.restore();
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SuitPainter old) =>
      old.suit != suit || old.color != color || old.shadows != shadows;
}

/// ودجت أيقونة متجهة عالية الجودة للرمز تناسب أوراق اللعب وواجهات المستخدم.
class SuitIcon extends StatelessWidget {
  const SuitIcon({
    super.key,
    required this.suit,
    required this.size,
    this.color,
    this.shadows,
  });

  const SuitIcon.spades({
    super.key,
    required this.size,
    this.color,
    this.shadows,
  }) : suit = Suit.spades;

  const SuitIcon.hearts({
    super.key,
    required this.size,
    this.color,
    this.shadows,
  }) : suit = Suit.hearts;

  const SuitIcon.diamonds({
    super.key,
    required this.size,
    this.color,
    this.shadows,
  }) : suit = Suit.diamonds;

  const SuitIcon.clubs({
    super.key,
    required this.size,
    this.color,
    this.shadows,
  }) : suit = Suit.clubs;

  factory SuitIcon.fromSymbol(
    String symbol, {
    Key? key,
    required double size,
    Color? color,
    List<Shadow>? shadows,
  }) {
    final suit = SuitExtension.fromSymbol(symbol) ?? Suit.spades;
    return SuitIcon(
      key: key,
      suit: suit,
      size: size,
      color: color,
      shadows: shadows,
    );
  }

  final Suit suit;
  final double size;
  final Color? color;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final defaultColor = suit.isRed ? AppColors.cardRed : AppColors.cardBlack;
    final effectiveColor = color ?? defaultColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: SuitPainter(
          suit: suit,
          color: effectiveColor,
          shadows: shadows,
        ),
      ),
    );
  }
}

extension SuitExtension on Suit {
  static Suit? fromSymbol(String symbol) {
    switch (symbol) {
      case '♠':
      case '♠️':
        return Suit.spades;
      case '♥':
      case '♥️':
      case '❤':
        return Suit.hearts;
      case '♦':
      case '♦️':
        return Suit.diamonds;
      case '♣':
      case '♣️':
        return Suit.clubs;
      default:
        return null;
    }
  }
}
