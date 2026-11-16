import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// أرضية وسجاد الصالة الملكية الفاخرة (المحيط الخلفي حول طاولة اللعب):
/// أرضية مخملية زمردية ملكية عميقة مزينة بنقوش الأرابيسك الإسلامية الذهبية
/// وإضاءة سينمائية دافئة تبرز طاولة اللعب في المنتصف كالجوهرة.
class DiwaniyaTableSurface extends StatelessWidget {
  const DiwaniyaTableSurface({super.key});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary يعزل الخلفية الثابتة بالكامل عن طبقة اللعب فلا يُعاد رسمها أثناء حركة الورق
    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.06),
            radius: 1.18,
            colors: [
              Color(0xFF093E2B), // زمردي ملكي دافئ في المركز حول الطاولة
              Color(0xFF05271B), // زمردي مخملي ليلي عميق
              Color(0xFF02120C), // أطراف الغرفة الداكنة المشبعة
            ],
            stops: [0.0, 0.56, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // نقوش الأرابيسك والزخارف الهندسية الملكية المذهبة الهادئة في الخلفية
            const CustomPaint(painter: _RoyalArabesqueCarpetPainter()),

            // هالة إضاءة ذهبية دافئة ثابتة خلف الطاولة الوسطية لإبرازها ثلاثياً دون استهلاك الرسوميات
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.04),
                  radius: 0.76,
                  colors: [
                    AppColors.gold.withAlpha(32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // تظليل محيطي ناعم وفاخر (Cinematic Vignette) يركز العين على الطاولة واللاعبين
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.08,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(165),
                  ],
                  stops: const [0.58, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoyalArabesqueCarpetPainter extends CustomPainter {
  const _RoyalArabesqueCarpetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldLinePaint = Paint()
      ..color = AppColors.gold.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    final goldStarPaint = Paint()
      ..color = AppColors.goldLight.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;

    final emeraldAccent = Paint()
      ..color = const Color(0xFF14754F).withAlpha(26)
      ..style = PaintingStyle.fill;

    // شبكة الزخارف الإسلامية الملكية (النجوم الثمانية المتداخلة والأرابيسك الذهبي)
    const tile = 72.0;
    for (double y = -tile / 2; y < size.height + tile; y += tile) {
      for (double x = -tile / 2; x < size.width + tile; x += tile) {
        final center = Offset(x, y);
        _drawEightPointStar(canvas, center, 18, goldStarPaint);
        _drawDiamond(canvas, center, 8, emeraldAccent);
        _drawDiamond(canvas, center, 24, goldLinePaint);
      }
    }

    // شريط إطار زخرفي ملكي مذهب على الحواف العلوية والسفلية
    final borderOuter = Paint()
      ..color = AppColors.gold.withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final borderInner = Paint()
      ..color = AppColors.goldLight.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    canvas.drawLine(const Offset(0, 3), Offset(size.width, 3), borderOuter);
    canvas.drawLine(const Offset(0, 6), Offset(size.width, 6), borderInner);
    canvas.drawLine(
      Offset(0, size.height - 3),
      Offset(size.width, size.height - 3),
      borderOuter,
    );
    canvas.drawLine(
      Offset(0, size.height - 6),
      Offset(size.width, size.height - 6),
      borderInner,
    );
  }

  void _drawDiamond(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawEightPointStar(Canvas canvas, Offset c, double r, Paint paint) {
    // نجمة ثمانية إسلامية مكونة من 8 رؤوس بتناسق هندسي رفيع
    final half = r * 0.7071;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + half * 0.45, c.dy - half * 0.45)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + half * 0.45, c.dy + half * 0.45)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - half * 0.45, c.dy + half * 0.45)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - half * 0.45, c.dy - half * 0.45)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
