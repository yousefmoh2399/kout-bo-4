import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/card.dart';

/// بطاقة لعب فاخرة بتصميم كلاسيكي أصيل (توزيع حقيقي للرموز، رسومات ملكية، ولمعة ورقية).
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    this.width = 58,
    this.dimmed = false,
    this.highlighted = false,
  });

  final PlayingCard card;
  final double width;
  final bool dimmed;
  final bool highlighted;

  double get height => width * 1.44;

  @override
  Widget build(BuildContext context) {
    final isRed = card.isJoker ? card.isRedJoker : card.suit!.isRed;
    final color = isRed ? AppColors.cardRed : AppColors.cardBlack;

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFDFBF4), Color(0xFFF4EFE1)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(width * 0.13),
        border: Border.all(
          color: highlighted ? AppColors.gold : const Color(0xFFD2C9B6),
          width: highlighted ? 2.2 : 1.0,
        ),
        boxShadow: [
          if (highlighted)
            BoxShadow(
              color: AppColors.gold.withAlpha(200),
              blurRadius: 14,
              spreadRadius: 1.5,
              offset: const Offset(0, -2),
            ),
          BoxShadow(
            color: Colors.black.withAlpha(dimmed ? 50 : 110),
            blurRadius: highlighted ? 10 : 6,
            offset: Offset(0, highlighted ? 5 : 2.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.12),
        child: Stack(
          children: [
            // إطار داخلي دقيق يحدد حافة الورقة
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(max(2.0, width * 0.045)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.09),
                  border: Border.all(
                    color: highlighted
                        ? AppColors.gold.withAlpha(110)
                        : (isRed
                            ? AppColors.cardRed.withAlpha(26)
                            : Colors.black.withAlpha(20)),
                    width: 0.7,
                  ),
                ),
              ),
            ),
            // محتوى الورقة
            if (card.isJoker) _buildJoker() else _buildSuited(color),
            // طبقة التعتيم النظيفة للأوراق غير المتاحة حالياً
            if (dimmed)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(95),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildJoker() {
    final isRed = card.isRedJoker;
    final accent = isRed ? AppColors.cardRed : AppColors.cardBlack;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: width * 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.auto_awesome,
                size: width * 0.18,
                color: isRed ? AppColors.goldDark : Colors.blueGrey.shade700,
              ),
              Text(
                'JOKER',
                style: TextStyle(
                  fontSize: width * 0.115,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 0.4,
                  height: 1,
                ),
              ),
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: width * 0.54,
                    height: width * 0.54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isRed
                            ? const [Color(0xFFFFF5DD), Color(0xFFFFD898)]
                            : const [Color(0xFFF3F6F9), Color(0xFFD0D9DF)],
                      ),
                      border: Border.all(
                        color: isRed ? AppColors.gold : Colors.blueGrey.shade500,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isRed ? AppColors.gold : Colors.black).withAlpha(55),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: Size(width * 0.30, width * 0.28),
                      painter: _JesterCrownPainter(color: accent),
                    ),
                  ),
                  SizedBox(height: width * 0.04),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.10, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.gold.withAlpha(150), width: 0.6),
                    ),
                    child: Text(
                      isRed ? 'الجيكر' : 'الميكر',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: width * 0.16,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: pi,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: width * 0.18,
                  color: isRed ? AppColors.goldDark : Colors.blueGrey.shade700,
                ),
                Text(
                  'JOKER',
                  style: TextStyle(
                    fontSize: width * 0.115,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuited(Color color) {
    final rank = card.rank!;
    final suit = card.suit!;
    final isFace = rank == Rank.king || rank == Rank.queen || rank == Rank.jack;

    return Stack(
      children: [
        // المؤشر العلوي
        Positioned(
          top: width * 0.075,
          left: width * 0.08,
          child: _CornerIndex(rank: rank.label, suit: suit.symbol, color: color, width: width),
        ),

        // المركز: صور ملكية / آص مزخرف / توزيع رموز حقيقي للأرقام
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.21,
              vertical: width * 0.17,
            ),
            child: isFace
                ? _buildFaceCenter(rank, suit, color)
                : (rank == Rank.ace
                    ? _buildAceCenter(suit, color)
                    : _buildPipGrid(rank, suit, color)),
          ),
        ),

        // المؤشر السفلي المعكوس 180 درجة
        Positioned(
          bottom: width * 0.075,
          right: width * 0.08,
          child: Transform.rotate(
            angle: pi,
            child: _CornerIndex(rank: rank.label, suit: suit.symbol, color: color, width: width),
          ),
        ),
      ],
    );
  }

  Widget _buildAceCenter(Suit suit, Color color) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: width * 0.56,
          height: width * 0.56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.goldLight.withAlpha(60),
                Colors.transparent,
              ],
            ),
            border: Border.all(color: AppColors.gold.withAlpha(110), width: 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            suit.symbol,
            style: TextStyle(
              fontSize: width * 0.44,
              color: color,
              height: 1,
              shadows: [
                Shadow(color: Colors.black.withAlpha(28), blurRadius: 3, offset: const Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceCenter(Rank rank, Suit suit, Color color) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: width * 0.54,
          height: width * 0.84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.goldDark.withAlpha(150), width: 1.1),
            gradient: LinearGradient(
              colors: [
                (suit.isRed ? AppColors.cardRed : const Color(0xFF1E3A5F)).withAlpha(22),
                AppColors.gold.withAlpha(24),
                (suit.isRed ? AppColors.cardRed : const Color(0xFF1E3A5F)).withAlpha(18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // خط داخلي ذهبي للصورة
              Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.gold.withAlpha(90), width: 0.6),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rank == Rank.king)
                    CustomPaint(
                      size: Size(width * 0.25, width * 0.18),
                      painter: _CrownPainter(color: AppColors.goldDark),
                    )
                  else if (rank == Rank.queen)
                    CustomPaint(
                      size: Size(width * 0.25, width * 0.18),
                      painter: _TiaraPainter(color: AppColors.goldDark),
                    )
                  else
                    Icon(Icons.shield_rounded, size: width * 0.22, color: AppColors.goldDark),
                  SizedBox(height: width * 0.03),
                  Text(
                    suit.symbol,
                    style: TextStyle(fontSize: width * 0.27, color: color, height: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// توزيع رموز الورقة الحقيقي (Pips) للأرقام 7, 8, 9, 10.
  Widget _buildPipGrid(Rank rank, Suit suit, Color color) {
    final pips = _pipPositions(rank);
    final pipSize = width * 0.21;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final p in pips)
              Positioned(
                left: (w * p.$1) - pipSize / 2,
                top: (h * p.$2) - pipSize / 2,
                width: pipSize,
                height: pipSize,
                child: Transform.rotate(
                  angle: p.$3 ? pi : 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      suit.symbol,
                      style: TextStyle(fontSize: pipSize, color: color, height: 1),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// إحداثيات (x, y, معكوس) لكل رتبة عددية (7..10).
  List<(double, double, bool)> _pipPositions(Rank rank) {
    switch (rank) {
      case Rank.seven:
        return const [
          (0.22, 0.12, false), (0.78, 0.12, false),
          (0.50, 0.30, false),
          (0.22, 0.50, false), (0.78, 0.50, false),
          (0.22, 0.88, true),  (0.78, 0.88, true),
        ];
      case Rank.eight:
        return const [
          (0.22, 0.12, false), (0.78, 0.12, false),
          (0.50, 0.30, false),
          (0.22, 0.50, false), (0.78, 0.50, false),
          (0.50, 0.70, true),
          (0.22, 0.88, true),  (0.78, 0.88, true),
        ];
      case Rank.nine:
        return const [
          (0.22, 0.10, false), (0.78, 0.10, false),
          (0.22, 0.36, false), (0.78, 0.36, false),
          (0.50, 0.50, false),
          (0.22, 0.64, true),  (0.78, 0.64, true),
          (0.22, 0.90, true),  (0.78, 0.90, true),
        ];
      case Rank.ten:
        return const [
          (0.22, 0.10, false), (0.78, 0.10, false),
          (0.50, 0.23, false),
          (0.22, 0.36, false), (0.78, 0.36, false),
          (0.22, 0.64, true),  (0.78, 0.64, true),
          (0.50, 0.77, true),
          (0.22, 0.90, true),  (0.78, 0.90, true),
        ];
      default:
        return const [(0.50, 0.50, false)];
    }
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(0, size.height * 0.22)
      ..lineTo(size.width * 0.28, size.height * 0.54)
      ..lineTo(size.width * 0.50, size.height * 0.08)
      ..lineTo(size.width * 0.72, size.height * 0.54)
      ..lineTo(size.width, size.height * 0.22)
      ..lineTo(size.width, size.height * 0.82)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.87, size.width, size.height * 0.13),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
}

class _TiaraPainter extends CustomPainter {
  const _TiaraPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.84)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.35, size.width * 0.5, size.height * 0.10)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.35, size.width, size.height * 0.84)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.10), size.width * 0.07, paint);
  }

  @override
  bool shouldRepaint(covariant _TiaraPainter oldDelegate) => oldDelegate.color != color;
}

class _JesterCrownPainter extends CustomPainter {
  const _JesterCrownPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.82)
      ..quadraticBezierTo(0, size.height * 0.35, size.width * 0.18, size.height * 0.18)
      ..lineTo(size.width * 0.38, size.height * 0.52)
      ..lineTo(size.width * 0.50, size.height * 0.08)
      ..lineTo(size.width * 0.62, size.height * 0.52)
      ..lineTo(size.width * 0.82, size.height * 0.18)
      ..quadraticBezierTo(size.width, size.height * 0.35, size.width * 0.88, size.height * 0.82)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.16), size.width * 0.06, paint);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.08), size.width * 0.07, paint);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.16), size.width * 0.06, paint);
  }

  @override
  bool shouldRepaint(covariant _JesterCrownPainter oldDelegate) => oldDelegate.color != color;
}

class _CornerIndex extends StatelessWidget {
  const _CornerIndex({
    required this.rank,
    required this.suit,
    required this.color,
    required this.width,
  });

  final String rank;
  final String suit;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          rank,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: width * 0.225,
            height: 0.95,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontSize: width * 0.185,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

/// ظهر الورقة الفاخر بنمط الزخرفة الملكية (Royal Arabesque Guilloché & Gold Medallion).
class CardBackView extends StatelessWidget {
  const CardBackView({super.key, this.width = 32, this.label});

  final double width;
  final String? label;

  double get height => width * 1.44;

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.13;
    final outerPad = max(1.3, width * 0.068);
    final innerRadius = max(2.0, radius - outerPad * 0.65);
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(outerPad),
        decoration: BoxDecoration(
          // حافة ورق اللعب العاجي الفاخر مثل أوراق اللعب العالمية
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F0E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFFB8AA8E),
            width: max(0.6, width * 0.018),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(135),
              blurRadius: max(3.5, width * 0.12),
              offset: Offset(0, max(1.5, width * 0.05)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // خلفية عنابية ملكية عميقة بتدرج مركزي غني
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Color(0xFF9C162E),
                      Color(0xFF6B0B1C),
                      Color(0xFF3E040E),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                ),
              ),
              // زخرفة هندسية عربية وميدالية ذهبية في الوسط
              CustomPaint(
                painter: _CardBackPainter(
                  detailed: width >= 26,
                  showMedallion: label == null,
                ),
              ),
              // لمعة حريرية مائلة أعلى الورقة لإبراز ملمس الكوتشينة الأصلي
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(34),
                      Colors.transparent,
                      Colors.black.withAlpha(24),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              if (label != null)
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.15,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold, width: 1),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontWeight: FontWeight.w900,
                        fontSize: width * 0.42,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter({
    required this.detailed,
    required this.showMedallion,
  });

  final bool detailed;
  final bool showMedallion;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // 1. شبكة معيّنات زخرفية دقيقة متناسقة مع حجم الورقة
    final latticePaint = Paint()
      ..color = AppColors.goldLight.withAlpha(detailed ? 42 : 52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = detailed ? max(0.55, w * 0.012) : 0.7;

    final step = max(5.0, w * 0.19);
    for (double y = 0; y <= h + step; y += step) {
      for (double x = 0; x <= w + step; x += step) {
        final p = Path()
          ..moveTo(x, y - step * 0.5)
          ..lineTo(x + step * 0.5, y)
          ..lineTo(x, y + step * 0.5)
          ..lineTo(x - step * 0.5, y)
          ..close();
        canvas.drawPath(p, latticePaint);
      }
    }

    // 2. إطار ذهبي مزدوج أنيق
    final m1 = max(1.5, w * 0.065);
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(m1, m1, w - m1, h - m1),
      Radius.circular(max(1.5, w * 0.055)),
    );
    canvas.drawRRect(
      outerRect,
      Paint()
        ..color = AppColors.goldLight.withAlpha(205)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.022),
    );

    if (detailed) {
      final m2 = m1 + max(2.2, w * 0.055);
      final innerRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(m2, m2, w - m2, h - m2),
        Radius.circular(max(1.2, w * 0.04)),
      );
      canvas.drawRRect(
        innerRect,
        Paint()
          ..color = AppColors.gold.withAlpha(135)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.55, w * 0.012),
      );

      // زوايا ذهبية مقوّسة (Corner Filigree)
      final cornerR = w * 0.14;
      final cornerPaint = Paint()
        ..color = AppColors.goldLight.withAlpha(165)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, w * 0.016);
      canvas.drawCircle(Offset(m2, m2), cornerR * 0.45, cornerPaint);
      canvas.drawCircle(Offset(w - m2, m2), cornerR * 0.45, cornerPaint);
      canvas.drawCircle(Offset(m2, h - m2), cornerR * 0.45, cornerPaint);
      canvas.drawCircle(Offset(w - m2, h - m2), cornerR * 0.45, cornerPaint);
    }

    if (!showMedallion) return;

    // 3. ميدالية وسطية ملكية بنجمة ثمانية ذهبية (شعار الكوتشينة)
    final medR = w * 0.25;
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF5D0716), Color(0xFF2B030A)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: medR)),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      medR,
      Paint()
        ..color = AppColors.goldLight.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.024),
    );

    if (detailed) {
      canvas.drawCircle(
        Offset(cx, cy),
        medR * 0.78,
        Paint()
          ..color = AppColors.gold.withAlpha(140)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.5, w * 0.012),
      );
    }

    // نجمة ثمانية متماثلة في مركز الورقة
    final starPaint = Paint()
      ..color = AppColors.goldLight
      ..style = PaintingStyle.fill;
    final outerStarR = medR * 0.62;
    final innerStarR = medR * 0.26;
    final starPath = Path();
    for (var i = 0; i < 16; i++) {
      final angle = (i * pi / 8) - pi / 2;
      final r = i.isEven ? outerStarR : innerStarR;
      final px = cx + cos(angle) * r;
      final py = cy + sin(angle) * r;
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) =>
      oldDelegate.detailed != detailed || oldDelegate.showMedallion != showMedallion;
}
