import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/card.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import '../strings.dart';
import '../suit_icon.dart';

/// اتجاه انحناء مروحة الكروت نحو الطاولة
enum FanDirection { facingRight, facingLeft, facingCenter }

// ============================================================================
// 1. الرسام المتجهي لأفاتارات الشخصيات الكويتية الأصيلة (Kuwaiti Avatars)
// ============================================================================
class KuwaitiAvatarPainter extends CustomPainter {
  final int seat;
  final bool isTurn;

  const KuwaitiAvatarPainter({
    required this.seat,
    this.isTurn = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 1. الدشداشة والياقة والأكتاف
    Paint bishtPaint;
    switch (seat) {
      case 0: // أنت: بشت أسود مقصب بالذهب (VIP كويتي أصيل)
        bishtPaint = Paint()..color = const Color(0xFF14171A);
        break;
      case 1: // الخصم الأيمن (عبود): ثوب خمري ملكي
        bishtPaint = Paint()..color = const Color(0xFF4E1414);
        break;
      case 2: // الشريك: ثوب كحلي ديوانية فاخر
        bishtPaint = Paint()..color = const Color(0xFF0C2F38);
        break;
      default: // الخصم الأيسر (عباس): ثوب أرجواني عميق
        bishtPaint = Paint()..color = const Color(0xFF2C103A);
        break;
    }

    final shoulderPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.74)
      ..quadraticBezierTo(cx, h * 0.64, w, h * 0.74)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(shoulderPath, bishtPaint);

    // ياقة الدشداشة الكويتية البيضاء
    final collarPaint = Paint()
      ..color = const Color(0xFFF9F9F9)
      ..style = PaintingStyle.fill;
    final collarPath = Path()
      ..moveTo(cx - w * 0.16, h)
      ..lineTo(cx - w * 0.11, h * 0.74)
      ..lineTo(cx, h * 0.80)
      ..lineTo(cx + w * 0.11, h * 0.74)
      ..lineTo(cx + w * 0.16, h)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // زري البشت المذهب للمقعد 0 (VIP Player)
    if (seat == 0) {
      final goldZari = Paint()
        ..color = AppColors.goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawLine(
        Offset(cx - w * 0.11, h * 0.74),
        Offset(cx - w * 0.16, h),
        goldZari,
      );
      canvas.drawLine(
        Offset(cx + w * 0.11, h * 0.74),
        Offset(cx + w * 0.16, h),
        goldZari,
      );
    }

    // 2. الرقبة
    final skinPaint = Paint()
      ..color = const Color(0xFFE8BB94)
      ..style = PaintingStyle.fill;
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.65),
        width: w * 0.22,
        height: h * 0.18,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, skinPaint);

    // 3. الرأس والوجه
    final faceRect = Rect.fromCenter(
      center: Offset(cx, h * 0.46),
      width: w * 0.48,
      height: h * 0.44,
    );
    canvas.drawOval(faceRect, skinPaint);

    // تظليل الوجنتين الناعم
    final cheekPaint = Paint()
      ..color = const Color(0xFFD69A70).withAlpha(110)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - w * 0.14, h * 0.48), w * 0.055, cheekPaint);
    canvas.drawCircle(Offset(cx + w * 0.14, h * 0.48), w * 0.055, cheekPaint);

    // 4. العيون والحواجب
    final eyeWhite = Paint()..color = Colors.white;
    final irisPaint = Paint()..color = const Color(0xFF221609);
    final glintPaint = Paint()..color = Colors.white;
    final browPaint = Paint()
      ..color = const Color(0xFF1E1308)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final eyeY = h * 0.44;
    final eyeSpacing = w * 0.11;

    for (final dir in [-1.0, 1.0]) {
      final eyeX = cx + dir * eyeSpacing;
      // بياض العين
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(eyeX, eyeY),
          width: w * 0.09,
          height: h * 0.075,
        ),
        eyeWhite,
      );
      // بؤبؤ العين
      canvas.drawCircle(Offset(eyeX, eyeY), w * 0.032, irisPaint);
      // بريق العين
      canvas.drawCircle(Offset(eyeX - 0.8, eyeY - 0.8), 0.9, glintPaint);

      // رسم الحواجب
      final browPath = Path()
        ..moveTo(eyeX - dir * w * 0.045, eyeY - h * 0.065)
        ..quadraticBezierTo(
          eyeX,
          eyeY - h * 0.082,
          eyeX + dir * w * 0.045,
          eyeY - h * 0.06,
        );
      canvas.drawPath(browPath, browPaint);
    }

    // الأنف
    final nosePaint = Paint()
      ..color = const Color(0xFFCA9068)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final nosePath = Path()
      ..moveTo(cx, h * 0.44)
      ..lineTo(cx - 0.5, h * 0.51)
      ..lineTo(cx + 2.0, h * 0.51);
    canvas.drawPath(nosePath, nosePaint);

    // 5. الشارب واللحية الكويتية
    final hairPaint = Paint()
      ..color = const Color(0xFF22160A)
      ..style = PaintingStyle.fill;

    // شارب كويتي متناسق
    final stachePath = Path()
      ..moveTo(cx - w * 0.13, h * 0.55)
      ..quadraticBezierTo(cx - w * 0.05, h * 0.53, cx, h * 0.55)
      ..quadraticBezierTo(cx + w * 0.05, h * 0.53, cx + w * 0.13, h * 0.55)
      ..quadraticBezierTo(cx + w * 0.06, h * 0.585, cx, h * 0.565)
      ..quadraticBezierTo(cx - w * 0.06, h * 0.585, cx - w * 0.13, h * 0.55)
      ..close();
    canvas.drawPath(stachePath, hairPaint);

    // سكسوكة / لحية
    if (seat == 0 || seat == 1) {
      final beardPath = Path()
        ..moveTo(cx - w * 0.065, h * 0.60)
        ..quadraticBezierTo(cx, h * 0.66, cx + w * 0.065, h * 0.60)
        ..quadraticBezierTo(cx, h * 0.675, cx - w * 0.065, h * 0.60)
        ..close();
      canvas.drawPath(beardPath, hairPaint);
    }

    // 6. غطاء الرأس: الغترة والعقال أو الشماغ أو القحفية
    if (seat == 0 || seat == 2) {
      // غترة كويتية بيضاء مفرودة بأناقة
      final ghutraPaint = Paint()
        ..color = const Color(0xFFFCFCFC)
        ..style = PaintingStyle.fill;
      final ghutraShadow = Paint()
        ..color = const Color(0xFFD6D6D6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      // الأطراف المنسدلة على الكتفين
      final leftDrape = Path()
        ..moveTo(cx - w * 0.22, h * 0.35)
        ..lineTo(cx - w * 0.31, h * 0.76)
        ..quadraticBezierTo(cx - w * 0.22, h * 0.80, cx - w * 0.17, h * 0.72)
        ..close();
      canvas.drawPath(leftDrape, ghutraPaint);
      canvas.drawPath(leftDrape, ghutraShadow);

      final rightDrape = Path()
        ..moveTo(cx + w * 0.22, h * 0.35)
        ..lineTo(cx + w * 0.31, h * 0.76)
        ..quadraticBezierTo(cx + w * 0.22, h * 0.80, cx + w * 0.17, h * 0.72)
        ..close();
      canvas.drawPath(rightDrape, ghutraPaint);
      canvas.drawPath(rightDrape, ghutraShadow);

      // قبة الغترة العلوية
      final domePath = Path()
        ..moveTo(cx - w * 0.24, h * 0.34)
        ..quadraticBezierTo(cx, h * 0.15, cx + w * 0.24, h * 0.34)
        ..close();
      canvas.drawPath(domePath, ghutraPaint);

      // عقال كويتي أسود مبروم مزدوج
      final egalPaint = Paint()
        ..color = const Color(0xFF141414)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      final egalHighlight = Paint()
        ..color = const Color(0xFF5A5A5A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;

      final egalY1 = h * 0.27;
      canvas.drawLine(
        Offset(cx - w * 0.21, egalY1),
        Offset(cx + w * 0.21, egalY1),
        egalPaint,
      );
      canvas.drawLine(
        Offset(cx - w * 0.14, egalY1 - 0.5),
        Offset(cx + w * 0.14, egalY1 - 0.5),
        egalHighlight,
      );

      final egalY2 = h * 0.32;
      canvas.drawLine(
        Offset(cx - w * 0.22, egalY2),
        Offset(cx + w * 0.22, egalY2),
        egalPaint,
      );
      canvas.drawLine(
        Offset(cx - w * 0.15, egalY2 - 0.5),
        Offset(cx + w * 0.15, egalY2 - 0.5),
        egalHighlight,
      );
    } else if (seat == 1) {
      // شماغ أحمر بنقش ديوانية
      final shemaghBase = Paint()..color = const Color(0xFFF7F5F2);
      final redLine = Paint()
        ..color = const Color(0xFFBD2828)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;

      final leftDrape = Path()
        ..moveTo(cx - w * 0.22, h * 0.35)
        ..lineTo(cx - w * 0.31, h * 0.76)
        ..quadraticBezierTo(cx - w * 0.22, h * 0.80, cx - w * 0.17, h * 0.72)
        ..close();
      canvas.drawPath(leftDrape, shemaghBase);

      final rightDrape = Path()
        ..moveTo(cx + w * 0.22, h * 0.35)
        ..lineTo(cx + w * 0.31, h * 0.76)
        ..quadraticBezierTo(cx + w * 0.22, h * 0.80, cx + w * 0.17, h * 0.72)
        ..close();
      canvas.drawPath(rightDrape, shemaghBase);

      final domePath = Path()
        ..moveTo(cx - w * 0.24, h * 0.34)
        ..quadraticBezierTo(cx, h * 0.15, cx + w * 0.24, h * 0.34)
        ..close();
      canvas.drawPath(domePath, shemaghBase);

      for (double lx = cx - w * 0.18; lx <= cx + w * 0.18; lx += 4.5) {
        canvas.drawLine(Offset(lx, h * 0.20), Offset(lx + 2, h * 0.34), redLine);
      }

      final egalPaint = Paint()
        ..color = const Color(0xFF141414)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx - w * 0.21, h * 0.27),
        Offset(cx + w * 0.21, h * 0.27),
        egalPaint,
      );
      canvas.drawLine(
        Offset(cx - w * 0.22, h * 0.32),
        Offset(cx + w * 0.22, h * 0.32),
        egalPaint,
      );
    } else {
      // قحفية كويتية بيضاء بنقوش هندسية (المقعد 3)
      final taqiyahPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      final taqiyahBorder = Paint()
        ..color = const Color(0xFFD4D4D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final taqiyahPattern = Paint()
        ..color = const Color(0xFFA5A5A5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;

      final capRect = Rect.fromCenter(
        center: Offset(cx, h * 0.28),
        width: w * 0.46,
        height: h * 0.28,
      );
      canvas.drawArc(capRect, pi, pi, true, taqiyahPaint);
      canvas.drawArc(capRect, pi, pi, false, taqiyahBorder);

      for (double x = cx - w * 0.16; x <= cx + w * 0.16; x += 4.5) {
        canvas.drawLine(Offset(x, h * 0.23), Offset(x, h * 0.28), taqiyahPattern);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KuwaitiAvatarPainter oldDelegate) =>
      oldDelegate.seat != seat || oldDelegate.isTurn != isTurn;
}

// ============================================================================
// 2. بطاقة الأفاتار الاحترافية (PlayerAvatarCard) بتصميم Squircle وثيم المقعد
// ============================================================================
class PlayerAvatarCard extends StatelessWidget {
  const PlayerAvatarCard({
    super.key,
    required this.seat,
    required this.name,
    required this.isTurn,
    required this.sameTeam,
    this.size = 52.0,
    this.badgeIcon,
    this.badgeColor,
  });

  final int seat;
  final String name;
  final bool isTurn;
  final bool sameTeam;
  final double size;
  final IconData? badgeIcon;
  final Color? badgeColor;

  List<Color> get _themeGradient {
    switch (seat) {
      case 0: // أنت: زمردي كازينو ملكي فاخر
        return const [Color(0xFF137A52), Color(0xFF073825), Color(0xFF031C12)];
      case 2: // الشريك: تيل كحلي ملكي
        return const [Color(0xFF11758A), Color(0xFF073642), Color(0xFF031E26)];
      case 1: // الخصم الأيمن: ياقوتي خمري
        return const [Color(0xFF962323), Color(0xFF4C1010), Color(0xFF280707)];
      default: // الخصم الأيسر: بنفسجي إمبراطوري
        return const [Color(0xFF6B268C), Color(0xFF330E47), Color(0xFF1B0626)];
    }
  }

  IconData get _defaultBadge {
    switch (seat) {
      case 0:
        return Icons.workspace_premium_rounded; // تاج VIP
      case 2:
        return Icons.handshake_rounded; // مصافحة الشريك
      case 1:
        return Icons.shield_rounded; // درع الخصم
      default:
        return Icons.flash_on_rounded; // صاعقة الخصم
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;
    final badge = badgeIcon ?? _defaultBadge;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: RadialGradient(
            center: const Alignment(-0.2, -0.3),
            radius: 0.98,
            colors: _themeGradient,
          ),
          border: Border.all(
            color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(165),
            width: isTurn ? 2.2 : 1.3,
          ),
          boxShadow: [
            if (isTurn) ...[
              BoxShadow(
                color: AppColors.gold.withAlpha(150),
                blurRadius: 14,
                spreadRadius: 1.5,
              ),
              BoxShadow(
                color: sameTeam
                    ? const Color(0xFF2ECC71).withAlpha(90)
                    : const Color(0xFFE74C3C).withAlpha(90),
                blurRadius: 10,
              ),
            ],
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(max(4.0, radius - 1.5)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // رسم شخصية الأفاتار الكويتية بالمتجهات
              CustomPaint(
                painter: KuwaitiAvatarPainter(seat: seat, isTurn: isTurn),
              ),

              // شارة الرتبة والدور في الزاوية العلوية
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  width: size * 0.30,
                  height: size * 0.30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(180),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(200),
                      width: 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    badge,
                    size: size * 0.19,
                    color: badgeColor ?? AppColors.goldLight,
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

// ============================================================================
// 3. لوحة اسم اللاعب المذهبة (PlayerNamePlate)
// ============================================================================
class PlayerNamePlate extends StatelessWidget {
  const PlayerNamePlate({
    super.key,
    required this.name,
    this.isBot = false,
    this.isDealer = false,
    this.maxWidth = 68.0,
  });

  final String name;
  final bool isBot;
  final bool isDealer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xEE09141B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.gold.withAlpha(120),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBot) ...[
            const Icon(
              Icons.smart_toy_rounded,
              size: 10,
              color: Color(0xFF7DD3FC),
            ),
            const SizedBox(width: 2.5),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          if (isDealer) ...[
            const SizedBox(width: 3),
            const DealerChip(),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 4. مروحة الكروت المقوسة الحقيقية (CurvedCardFan)
// ============================================================================
class CurvedCardFan extends StatelessWidget {
  const CurvedCardFan({
    super.key,
    required this.count,
    this.direction = FanDirection.facingRight,
    this.compact = false,
  });

  final int count;
  final FanDirection direction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final visible = min(count, compact ? 5 : 7);
    final cardW = compact ? 10.0 : 14.0;
    final cardH = compact ? 14.5 : 20.0;
    final step = compact ? 2.4 : 3.8;
    final totalW = cardW + (visible - 1) * step + (compact ? 14.0 : 18.0);

    final fanStack = SizedBox(
      width: totalW,
      height: cardH + 4,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (var i = 0; i < visible; i++)
            Builder(
              builder: (_) {
                final frac = visible > 1 ? (i / (visible - 1) - 0.5) : 0.0;
                final angle = direction == FanDirection.facingLeft
                    ? -frac * 0.32
                    : frac * 0.32;
                final arcDy = (frac * frac) * (compact ? 2.0 : 3.0);

                return Positioned(
                  left: i * step,
                  top: arcDy,
                  child: Transform.rotate(
                    angle: angle,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: cardW,
                      height: cardH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 3,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                      child: CardBackView(width: cardW),
                    ),
                  ),
                );
              },
            ),

          // شارة رقم الكروت المتبقية
          Positioned(
            right: 0,
            bottom: compact ? 1 : 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 3.5 : 4.5,
                vertical: compact ? 0.5 : 1,
              ),
              decoration: BoxDecoration(
                color: const Color(0xF2071A24),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.gold.withAlpha(200),
                  width: 0.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: compact ? 8.5 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldLight,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return fanStack;
  }
}

// ============================================================================
// 5. فقاعة المزايدة والعقد الذكية (PlayerBidBubble)
// ============================================================================
class PlayerBidBubble extends StatelessWidget {
  const PlayerBidBubble({
    super.key,
    required this.tag,
    this.suit,
    this.isContractor = false,
  });

  final String tag;
  final Suit? suit;
  final bool isContractor;

  bool get _isPass => tag == S.pass || tag == 'طاف' || tag == 'باس';

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('bid_${tag}_$suit'),
      tween: Tween(begin: 0.65, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: _isPass
                ? const [Color(0xFF475569), Color(0xFF1E293B)]
                : (isContractor
                    ? const [Color(0xFFE5B83A), Color(0xFF9E720F)]
                    : const [Color(0xFF0284C7), Color(0xFF0369A1)]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isContractor ? AppColors.goldLight : Colors.white70,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isPass
                      ? Colors.black54
                      : (isContractor
                          ? AppColors.gold.withAlpha(120)
                          : const Color(0xFF0284C7).withAlpha(120))),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isContractor ? const Color(0xFF1A1202) : Colors.white,
                height: 1.05,
              ),
            ),
            if (suit != null) ...[
              const SizedBox(width: 3),
              SuitIcon(
                suit: suit!,
                size: 11,
                color: suit!.isRed
                    ? const Color(0xFFFF4848)
                    : (isContractor ? const Color(0xFF1A1202) : Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. محطة الشريك (PartnerStation - North)
// ============================================================================
class PartnerStation extends StatelessWidget {
  const PartnerStation({super.key, required this.state, required this.seat});

  final GameState state;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bloc = context.read<GameBloc>();
    final isTurn = s.actor == seat;
    final isDealer = s.dealer == seat;
    final isBot = s.autoSeats.contains(seat);
    final name = s.names[seat];
    final count = s.hands[seat].length;
    final tag = _seatTag(s, seat);
    final end = s.turnEndsAt;

    final avatar = PlayerAvatarCard(
      seat: seat,
      name: name,
      isTurn: isTurn,
      sameTeam: true,
      size: 48,
    );

    final Widget wrappedHead =
        (isTurn && end != null && bloc.turnSeconds > 0)
            ? TurnRing(
                endsAt: end,
                total: bloc.turnSeconds,
                playTick: false,
                size: 54,
                child: avatar,
              )
            : avatar;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (tag != null) ...[
          PlayerBidBubble(
            tag: tag,
            suit: s.trump,
            isContractor: s.bidder == seat,
          ),
          const SizedBox(width: 5),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            wrappedHead,
            const SizedBox(height: 3),
            PlayerNamePlate(
              name: name,
              isBot: isBot,
              isDealer: isDealer,
              maxWidth: 72,
            ),
          ],
        ),
        if (count > 0) ...[
          const SizedBox(width: 5),
          CurvedCardFan(count: count, direction: FanDirection.facingRight),
        ],
      ],
    );
  }
}

// ============================================================================
// 7. محطة الخصم الجانبي (SideStation - East / West)
// ============================================================================
class SideStation extends StatelessWidget {
  const SideStation({
    super.key,
    required this.state,
    required this.seat,
    required this.isRight,
  });

  final GameState state;
  final int seat;
  final bool isRight;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bloc = context.read<GameBloc>();
    final isTurn = s.actor == seat;
    final isDealer = s.dealer == seat;
    final isBot = s.autoSeats.contains(seat);
    final name = s.names[seat];
    final count = s.hands[seat].length;
    final tag = _seatTag(s, seat);
    final end = s.turnEndsAt;

    final isPortrait = MediaQuery.maybeOf(context) != null &&
        MediaQuery.of(context).size.height > MediaQuery.of(context).size.width;

    final avatar = PlayerAvatarCard(
      seat: seat,
      name: name,
      isTurn: isTurn,
      sameTeam: false,
      size: isPortrait ? 44 : 48,
    );

    final Widget wrappedHead =
        (isTurn && end != null && bloc.turnSeconds > 0)
            ? TurnRing(
                endsAt: end,
                total: bloc.turnSeconds,
                playTick: false,
                size: isPortrait ? 50 : 54,
                child: avatar,
              )
            : avatar;

    final avatarWithPlate = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wrappedHead,
        const SizedBox(height: 3),
        PlayerNamePlate(
          name: name,
          isBot: isBot,
          isDealer: isDealer,
          maxWidth: isPortrait ? 58 : 64,
        ),
        if (tag != null) ...[
          const SizedBox(height: 3),
          PlayerBidBubble(
            tag: tag,
            suit: s.trump,
            isContractor: s.bidder == seat,
          ),
        ],
      ],
    );

    if (isRight) {
      // الخصم الأيمن (East على يمين الشاشة): في وضع RTL الأفاتار على اليمين والمروحة على اليسار نحو الطاولة
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatarWithPlate,
          if (count > 0) ...[
            const SizedBox(width: 3),
            CurvedCardFan(
              count: count,
              direction: FanDirection.facingLeft,
              compact: isPortrait,
            ),
          ],
        ],
      );
    } else {
      // الخصم الأيسر (West على يسار الشاشة): في وضع RTL المروحة على اليمين نحو الطاولة والأفاتار على اليسار
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (count > 0) ...[
            CurvedCardFan(
              count: count,
              direction: FanDirection.facingRight,
              compact: isPortrait,
            ),
            const SizedBox(width: 3),
          ],
          avatarWithPlate,
        ],
      );
    }
  }
}

// ============================================================================
// 8. محطة اللاعب (PlayerStation - South / أنت)
// ============================================================================
class PlayerStation extends StatelessWidget {
  const PlayerStation({super.key, required this.state, required this.seat});

  final GameState state;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bloc = context.read<GameBloc>();
    final isTurn = s.actor == seat;
    final isDealer = s.dealer == seat;
    final isBot = s.autoSeats.contains(seat);
    final name = s.names[seat];
    final tag = _seatTag(s, seat);
    final end = s.turnEndsAt;
    final ourTricks = s.tricksWon[Rules.teamOf(seat)];

    final avatar = PlayerAvatarCard(
      seat: seat,
      name: name,
      isTurn: isTurn,
      sameTeam: true,
      size: 48,
    );

    final Widget wrappedHead =
        (isTurn && end != null && bloc.turnSeconds > 0)
            ? TurnRing(
                endsAt: end,
                total: bloc.turnSeconds,
                playTick: true,
                size: 54,
                child: avatar,
              )
            : avatar;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            wrappedHead,
            const SizedBox(height: 3),
            PlayerNamePlate(
              name: name,
              isBot: isBot,
              isDealer: isDealer,
              maxWidth: 68,
            ),
          ],
        ),
        if (tag != null) ...[
          const SizedBox(width: 5),
          PlayerBidBubble(
            tag: tag,
            suit: s.trump,
            isContractor: s.bidder == seat,
          ),
        ],
        if (ourTricks > 0) ...[
          const SizedBox(width: 6),
          TrickPileStack(count: ourTricks, sameTeam: true),
        ],
      ],
    );
  }
}

String? _seatTag(GameState s, int seat) {
  if (s.phase == GamePhase.bidding) {
    final b = s.bids[seat];
    if (b != null) return b == 0 ? S.pass : '$b';
  } else if (s.bidder == seat && s.phase != GamePhase.idle) {
    return S.bidder;
  }
  return null;
}

// ============================================================================
// 9. مكونات إضافية ومساعدة
// ============================================================================
class DealerChip extends StatelessWidget {
  const DealerChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.25, -0.3),
          colors: [
            Color(0xFFFFF7C2),
            Color(0xFFE5B83A),
            Color(0xFF9E7412),
          ],
        ),
        border: Border.all(color: AppColors.goldLight, width: 0.8),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: const Text(
        'D',
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w900,
          color: Color(0xFF261603),
          height: 1,
        ),
      ),
    );
  }
}

class MiniCardFan extends StatelessWidget {
  const MiniCardFan({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CurvedCardFan(count: count);
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    required this.isTurn,
    required this.sameTeam,
    required this.size,
    this.iconData,
  });

  final String name;
  final bool isTurn;
  final bool sameTeam;
  final double size;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    return PlayerAvatarCard(
      seat: sameTeam ? 0 : 1,
      name: name,
      isTurn: isTurn,
      sameTeam: sameTeam,
      size: size,
      badgeIcon: iconData,
    );
  }
}

class TurnRing extends StatefulWidget {
  const TurnRing({
    super.key,
    required this.endsAt,
    required this.total,
    required this.playTick,
    this.size = 46,
    required this.child,
  });

  final DateTime endsAt;
  final int total;
  final bool playTick;
  final double size;
  final Widget child;

  @override
  State<TurnRing> createState() => _TurnRingState();
}

class _TurnRingState extends State<TurnRing> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final left = widget.endsAt.difference(DateTime.now()).inSeconds;
      if (left != _lastSecond) {
        _lastSecond = left;
        if (widget.playTick && left >= 0 && left <= 4) {
          SoundService.instance.play(Sfx.tick);
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leftMs =
        max(0, widget.endsAt.difference(DateTime.now()).inMilliseconds);
    final frac =
        (leftMs / (widget.total * 1000)).clamp(0.0, 1.0).toDouble();
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            value: frac,
            strokeWidth: 2.8,
            color: frac < 0.25 ? AppColors.danger : AppColors.gold,
            backgroundColor: Colors.white24,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class TrickPileStack extends StatelessWidget {
  const TrickPileStack({
    super.key,
    required this.count,
    required this.sameTeam,
  });

  final int count;
  final bool sameTeam;

  @override
  Widget build(BuildContext context) {
    final layers = min(count, 5);
    return TweenAnimationBuilder<double>(
      key: ValueKey('pile_${sameTeam}_$count'),
      tween: Tween(begin: 1.20, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: SizedBox(
        width: 26,
        height: 24,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (var i = 0; i < layers; i++)
              Positioned(
                bottom: i * 1.3,
                left: 4 + (i.isEven ? -0.5 : 0.5),
                child: Transform.rotate(
                  angle: (i - (layers - 1) / 2) * 0.04,
                  child: const CardBackView(width: 13),
                ),
              ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                decoration: BoxDecoration(
                  color: sameTeam ? AppColors.gold : const Color(0xFFD9643A),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.black54, width: 0.7),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w900,
                    color: sameTeam ? const Color(0xFF1E1304) : Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
