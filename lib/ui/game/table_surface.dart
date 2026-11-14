import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// طاولة الديوانية الكويتية الملكية:
/// إطار خشب ساج مثمّن الحواف، شريط سدو كويتي على المحيط الخارجي،
/// جوخ مخملي عميق، وعلامة مائية لأبراج الكويت والنجمة الخليجية مع دلة وفناجين هادئة.
class DiwaniyaTableSurface extends StatefulWidget {
  const DiwaniyaTableSurface({super.key});

  @override
  State<DiwaniyaTableSurface> createState() => _DiwaniyaTableSurfaceState();
}

class _DiwaniyaTableSurfaceState extends State<DiwaniyaTableSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // أرضية الديوانية الرخامية الداكنة الدافئة
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.15,
          colors: [
            Color(0xFF1F120A),
            Color(0xFF110905),
            Color(0xFF070302),
          ],
          stops: [0.0, 0.65, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // نقشة أرضية الديوانية الهندسية الخفيفة خارج الطاولة
          const CustomPaint(painter: _DiwaniyaFloorPainter()),

          // جسم الطاولة المثمّن بإطار الخشب الكويتي وشريط السدو المحيطي
          Padding(
            padding: const EdgeInsets.all(6),
            child: ClipPath(
              clipper: const _OctagonChamferClipper(chamfer: 28),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF5A3118),
                      Color(0xFF2B1408),
                      Color(0xFF472411),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // شريط السدو الكويتي المنسوج على الإطار الخشبي فقط (بعيداً عن الورق)
                    const CustomPaint(painter: _SaduBorderPainter()),

                    // الحافة الجلدية المبطنة + الجوخ المخملي العميق
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipPath(
                        clipper: const _OctagonChamferClipper(chamfer: 22),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF120804),
                              width: 3.0,
                            ),
                            gradient: const RadialGradient(
                              center: Alignment(0, -0.04),
                              radius: 1.02,
                              colors: [
                                Color(0xFF187C50),
                                Color(0xFF0F5C3B),
                                Color(0xFF073B25),
                                Color(0xFF031D12),
                              ],
                              stops: [0.0, 0.42, 0.78, 1.0],
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // ظل داخلي عميق لإبراز عمق الطاولة
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.96,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withAlpha(125),
                                    ],
                                    stops: const [0.64, 1.0],
                                  ),
                                ),
                              ),
                              // إضاءة فانوس الديوانية الدافئة النابضة في القلب
                              AnimatedBuilder(
                                animation: _ambient,
                                builder: (context, _) {
                                  final pulse =
                                      0.055 + 0.045 * sin(_ambient.value * pi);
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 0.68,
                                        colors: [
                                          AppColors.goldLight
                                              .withAlpha((pulse * 255).round()),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // نسيج الجوخ + أبراج الكويت + النجمة + دلة القهوة الهادئة
                              const CustomPaint(
                                painter: _KuwaitiFeltPainter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OctagonChamferClipper extends CustomClipper<Path> {
  const _OctagonChamferClipper({required this.chamfer});

  final double chamfer;

  @override
  Path getClip(Size size) {
    final c = min(chamfer, min(size.width, size.height) * 0.12);
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(c, h)
      ..lineTo(0, h - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _OctagonChamferClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}

class _DiwaniyaFloorPainter extends CustomPainter {
  const _DiwaniyaFloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withAlpha(10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// نقشة السدو الكويتية الأصيلة على محيط الإطار الخشبي للطاولة.
class _SaduBorderPainter extends CustomPainter {
  const _SaduBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final crimson = Paint()..color = const Color(0xFF7B2121).withAlpha(175);
    final cream = Paint()..color = const Color(0xFFE7D3A3).withAlpha(145);
    final goldTrim = Paint()
      ..color = AppColors.gold.withAlpha(115)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const step = 18.0;
    // شريط علوي وسفلي من مثلثات السدو
    for (double x = 32; x < size.width - 32; x += step) {
      _drawDiamond(canvas, Offset(x, 5.0), 4.2, crimson);
      _drawDiamond(canvas, Offset(x + step / 2, 5.0), 2.1, cream);
      _drawDiamond(canvas, Offset(x, size.height - 5.0), 4.2, crimson);
      _drawDiamond(canvas, Offset(x + step / 2, size.height - 5.0), 2.1, cream);
    }

    // شريط أيمن وأيسر من مثلثات السدو
    for (double y = 32; y < size.height - 32; y += step) {
      _drawDiamond(canvas, Offset(5.0, y), 4.2, crimson);
      _drawDiamond(canvas, Offset(5.0, y + step / 2), 2.1, cream);
      _drawDiamond(canvas, Offset(size.width - 5.0, y), 4.2, crimson);
      _drawDiamond(canvas, Offset(size.width - 5.0, y + step / 2), 2.1, cream);
    }

    // خط نحاسي محيطي داخلي
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    canvas.drawRect(rect, goldTrim);
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

class _KuwaitiFeltPainter extends CustomPainter {
  const _KuwaitiFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. نسيج مخملي قطري ناعم
    final grain = Paint()
      ..color = Colors.white.withAlpha(4)
      ..strokeWidth = 0.7;
    const step = 13.0;
    for (double d = -size.height; d < size.width + size.height; d += step) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height * 0.45, size.height),
        grain,
      );
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final minDim = min(size.width, size.height);

    // 2. خط خياطة ذهبية مزدوجة داخل حافة الجوخ
    final stitch = Paint()
      ..color = AppColors.gold.withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final inset = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(18)),
      stitch,
    );

    // 3. النجمة الخليجية الثمانية + شارة أبراج الكويت الشفافة في القلب
    final r = minDim * 0.22;
    final starPaint = Paint()
      ..color = AppColors.gold.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (var k = 0; k < 2; k++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(k * pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r, height: r),
        starPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.85, starPaint);

    // علامة مائية لأبراج الكويت الثلاثة في قلب النجمة
    final towerPaint = Paint()
      ..color = AppColors.gold.withAlpha(22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final towerFill = Paint()..color = AppColors.gold.withAlpha(10);

    // البرج الرئيسي الأوسط
    final mainBaseY = cy + r * 0.34;
    final mainTopY = cy - r * 0.38;
    canvas.drawLine(
      Offset(cx - r * 0.06, mainBaseY),
      Offset(cx - r * 0.02, mainTopY),
      towerPaint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.06, mainBaseY),
      Offset(cx + r * 0.02, mainTopY),
      towerPaint,
    );
    canvas.drawCircle(Offset(cx, cy - r * 0.04), r * 0.13, towerFill);
    canvas.drawCircle(Offset(cx, cy - r * 0.04), r * 0.13, towerPaint);
    canvas.drawCircle(Offset(cx, cy - r * 0.22), r * 0.075, towerFill);
    canvas.drawCircle(Offset(cx, cy - r * 0.22), r * 0.075, towerPaint);

    // البرج الثاني (يسار)
    final leftX = cx - r * 0.22;
    canvas.drawLine(
      Offset(leftX - r * 0.03, mainBaseY),
      Offset(leftX, cy - r * 0.22),
      towerPaint,
    );
    canvas.drawCircle(Offset(leftX, cy - r * 0.02), r * 0.09, towerFill);
    canvas.drawCircle(Offset(leftX, cy - r * 0.02), r * 0.09, towerPaint);

    // البرج الثالث الرفيع (يمين)
    final rightX = cx + r * 0.22;
    canvas.drawLine(
      Offset(rightX + r * 0.02, mainBaseY),
      Offset(rightX, cy - r * 0.15),
      towerPaint,
    );

    // 4. أيقونة دلة قهوة كويتية هادئة في الزاوية (خارج مسار اللعب)
    final dallahX = size.width - 36.0;
    const dallahY = 36.0;
    final dallahPaint = Paint()
      ..color = AppColors.gold.withAlpha(32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // جسم الدلة
    canvas.drawOval(
      Rect.fromCenter(center: Offset(dallahX, dallahY + 3), width: 14, height: 18),
      dallahPaint,
    );
    // غطاء الدلة والمصب
    canvas.drawArc(
      Rect.fromCenter(center: Offset(dallahX, dallahY - 7), width: 8, height: 6),
      pi,
      pi,
      false,
      dallahPaint,
    );
    final spout = Path()
      ..moveTo(dallahX - 6, dallahY)
      ..quadraticBezierTo(dallahX - 15, dallahY - 7, dallahX - 17, dallahY - 2);
    canvas.drawPath(spout, dallahPaint);

    // 5. مسامير نحاسية مذهبة في الأركان
    final brassGlow = Paint()..color = AppColors.gold.withAlpha(42);
    final brassCore = Paint()..color = AppColors.goldLight.withAlpha(120);
    const pad = 22.0;
    for (final pt in [
      const Offset(pad, pad),
      Offset(size.width - pad, pad),
      Offset(pad, size.height - pad),
      Offset(size.width - pad, size.height - pad),
    ]) {
      canvas.drawCircle(pt, 5.0, brassGlow);
      canvas.drawCircle(pt, 2.2, brassCore);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
