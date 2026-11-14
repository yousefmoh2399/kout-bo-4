import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/card.dart';

/// بطاقة لعب فاخرة مصممة بمعايير الكازينوهات العالمية وألعاب الورق الخليجية.
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

  double get height => width * 1.42;

  @override
  Widget build(BuildContext context) {
    final isRed = card.isJoker ? card.isRedJoker : card.suit!.isRed;
    final color = isRed ? AppColors.cardRed : AppColors.cardBlack;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), AppColors.cardCream],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: highlighted ? AppColors.gold : const Color(0xFFD8D0C1),
          width: highlighted ? 2.2 : 1.0,
        ),
        boxShadow: [
          if (highlighted)
            BoxShadow(
              color: AppColors.gold.withAlpha(190),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          BoxShadow(
            color: Colors.black.withAlpha(dimmed ? 45 : 95),
            blurRadius: highlighted ? 8 : 5,
            offset: Offset(0, highlighted ? 4 : 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.11),
        child: Stack(
          children: [
            // إطار داخلي دقيق (Inner Hairline)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(max(2.0, width * 0.045)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.08),
                  border: Border.all(
                    color: highlighted
                        ? AppColors.gold.withAlpha(100)
                        : (isRed
                            ? AppColors.cardRed.withAlpha(24)
                            : Colors.black.withAlpha(18)),
                    width: 0.7,
                  ),
                ),
              ),
            ),
            // محتوى الورقة
            if (card.isJoker) _buildJoker(color) else _buildSuited(color),
            // طبقة التعتيم النظيفة للأوراق غير المتاحة حالياً
            if (dimmed)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoker(Color color) {
    final isRed = card.isRedJoker;
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
                size: width * 0.19,
                color: isRed ? AppColors.goldDark : Colors.blueGrey.shade700,
              ),
              Text(
                'JOKER',
                style: TextStyle(
                  fontSize: width * 0.115,
                  fontWeight: FontWeight.w900,
                  color: isRed ? AppColors.cardRed : AppColors.cardBlack,
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
                    width: width * 0.50,
                    height: width * 0.50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isRed
                            ? const [Color(0xFFFFF2D6), Color(0xFFFFD691)]
                            : const [Color(0xFFF1F5F8), Color(0xFFCFD8DC)],
                      ),
                      border: Border.all(
                        color: isRed ? AppColors.gold : Colors.blueGrey.shade400,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isRed ? AppColors.gold : Colors.black).withAlpha(45),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: Size(width * 0.28, width * 0.28),
                      painter: _CrownPainter(
                        color: isRed ? AppColors.cardRed : AppColors.cardBlack,
                      ),
                    ),
                  ),
                  SizedBox(height: width * 0.04),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.10, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isRed ? AppColors.cardRed : AppColors.cardBlack,
                      borderRadius: BorderRadius.circular(5),
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
                  size: width * 0.19,
                  color: isRed ? AppColors.goldDark : Colors.blueGrey.shade700,
                ),
                Text(
                  'JOKER',
                  style: TextStyle(
                    fontSize: width * 0.115,
                    fontWeight: FontWeight.w900,
                    color: isRed ? AppColors.cardRed : AppColors.cardBlack,
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
          left: width * 0.085,
          child: _CornerIndex(rank: rank.label, suit: suit.symbol, color: color, width: width),
        ),

        // المركز
        Center(
          child: isFace ? _buildFaceCenter(rank, suit, color) : _buildNumberCenter(suit, color),
        ),

        // المؤشر السفلي المعكوس 180 درجة
        Positioned(
          bottom: width * 0.075,
          right: width * 0.085,
          child: Transform.rotate(
            angle: pi,
            child: _CornerIndex(rank: rank.label, suit: suit.symbol, color: color, width: width),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceCenter(Rank rank, Suit suit, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: width * 0.48,
        height: width * 0.60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.goldDark.withAlpha(110),
            width: 1.0,
          ),
          gradient: LinearGradient(
            colors: [
              (suit.isRed ? AppColors.cardRed : AppColors.goldDark).withAlpha(24),
              (suit.isRed ? AppColors.cardRed : AppColors.goldDark).withAlpha(8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (rank == Rank.king)
              CustomPaint(
                size: Size(width * 0.24, width * 0.18),
                painter: _CrownPainter(color: AppColors.goldDark),
              )
            else if (rank == Rank.queen)
              Icon(Icons.diamond_outlined, size: width * 0.21, color: AppColors.goldDark)
            else
              Icon(Icons.shield_outlined, size: width * 0.21, color: AppColors.goldDark),
            SizedBox(height: width * 0.02),
            Text(
              suit.symbol,
              style: TextStyle(fontSize: width * 0.25, color: color, height: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberCenter(Suit suit, Color color) {
    return Text(
      suit.symbol,
      style: TextStyle(
        fontSize: width * 0.50,
        color: color,
        height: 1,
        shadows: [
          Shadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
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
      ..moveTo(0, size.height * 0.85)
      ..lineTo(0, size.height * 0.25)
      ..lineTo(size.width * 0.28, size.height * 0.55)
      ..lineTo(size.width * 0.50, size.height * 0.10)
      ..lineTo(size.width * 0.72, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.85)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.88, size.width, size.height * 0.12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
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
            fontSize: width * 0.23,
            height: 0.95,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontSize: width * 0.19,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

/// ظهر الورقة الفاخر بنمط الزخرفة الملكية (Royal Guilloche Lattice).
class CardBackView extends StatelessWidget {
  const CardBackView({super.key, this.width = 32, this.label});

  final double width;
  final String? label;

  double get height => width * 1.42;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8C1426), Color(0xFF5D0A16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white, width: max(1.0, width * 0.055)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.1),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardBackPainter(),
              ),
            ),
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(max(1.5, width * 0.08)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.06),
                  border: Border.all(color: AppColors.goldLight.withAlpha(160), width: 0.8),
                ),
              ),
            ),
            if (label != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: width * 0.15, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(175),
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
              )
            else
              Container(
                width: width * 0.40,
                height: width * 0.40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF470610),
                  border: Border.all(color: AppColors.gold, width: 0.9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '♠',
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: width * 0.22,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const step = 6.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
