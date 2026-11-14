import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// أرضية وسجاد الديوانية الكويتية الملكية (المحيط الخلفي حول طاولة اللعب):
/// سجاد ديواني داكن بنقش سدو هندسي هادئ وإضاءة سقف دافئة تبرز طاولة اللعب في المنتصف.
class DiwaniyaTableSurface extends StatelessWidget {
  const DiwaniyaTableSurface({super.key});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary يعزل الخلفية الثابتة بالكامل عن طبقة اللعب فلا يُعاد رسمها أثناء حركة الورق
    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.08),
            radius: 1.15,
            colors: [
              Color(0xFF162436), // كحلي ديواني دافئ في المركز حول الطاولة
              Color(0xFF0D1724), // كحلي ليلي عميق
              Color(0xFF070C14), // أطراف الغرفة الداكنة
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // نقش سجاد الديوانية الكويتي الهندسي الهادئ في الخلفية
            const CustomPaint(painter: _DiwaniyaCarpetPainter()),

            // هالة إضاءة دافئة ثابتة خلف الطاولة الوسطية لإبرازها ثلاثياً دون استهلاك معالج الرسوميات
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.05),
                  radius: 0.72,
                  colors: [
                    AppColors.gold.withAlpha(26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // تظليل محيطي ناعم (Vignette) يركز العين على الطاولة واللاعبين
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(145),
                  ],
                  stops: const [0.62, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiwaniyaCarpetPainter extends CustomPainter {
  const _DiwaniyaCarpetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFD4AF37).withAlpha(14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    final crimsonAccent = Paint()
      ..color = const Color(0xFF8B2635).withAlpha(22)
      ..style = PaintingStyle.fill;

    final tealAccent = Paint()
      ..color = const Color(0xFF1F6E66).withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // شبكة زخارف سجاد الديوانية (معينات السدو والنجوم الثمانية المتكررة بهدوء)
    const tile = 68.0;
    for (double y = -tile / 2; y < size.height + tile; y += tile) {
      for (double x = -tile / 2; x < size.width + tile; x += tile) {
        final center = Offset(x, y);
        _drawDiamond(canvas, center, 22, linePaint);
        _drawDiamond(canvas, center, 13, tealAccent);
        _drawDiamond(canvas, center, 4.5, crimsonAccent);
      }
    }

    // شريط سدو تقليدي خفيف على الحافة العلوية والسفلية لأرضية الديوانية
    final borderPaint = Paint()
      ..color = AppColors.gold.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(0, 4), Offset(size.width, 4), borderPaint);
    canvas.drawLine(
      Offset(0, size.height - 4),
      Offset(size.width, size.height - 4),
      borderPaint,
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
