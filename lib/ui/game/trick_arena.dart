import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/card.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import '../suit_icon.dart';
import 'game_hud.dart';

// ============================================================================
// 1. رسام الطاولة ثلاثية الأبعاد الفاخرة (Diwaniya 3D Table Painter)
// ============================================================================
class Diwaniya3DTablePainter extends CustomPainter {
  final bool isLandscape;
  final bool isWinnerActive;

  const Diwaniya3DTablePainter({
    required this.isLandscape,
    this.isWinnerActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // أبعاد وهندسة الطاولة ثلاثية الأبعاد
    final apronH = isLandscape ? 28.0 : 22.0;
    final shadowH = isLandscape ? 16.0 : 12.0;
    final padX = isLandscape ? 12.0 : 8.0;
    final topY = isLandscape ? 8.0 : 6.0;
    final bottomY = h - apronH - shadowH;
    final taper = isLandscape ? 0.055 : 0.065; // نسبة الميل المنظوري (Trapezoid)

    // نقاط السطح العلوي
    final tl = Offset(padX + w * taper, topY);
    final tr = Offset(w - padX - w * taper, topY);
    final br = Offset(w - padX, bottomY);
    final bl = Offset(padX, bottomY);

    // 1. ظل الطاولة على الأرضية (Floor Drop Shadow) يعطي إحساساً بارتفاع الطاولة وتجسيمها
    final shadowPath = Path()
      ..moveTo(bl.dx - 6, bottomY + apronH * 0.3)
      ..lineTo(br.dx + 6, bottomY + apronH * 0.3)
      ..lineTo(br.dx + 12, bottomY + apronH + shadowH)
      ..lineTo(bl.dx - 12, bottomY + apronH + shadowH)
      ..close();

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withAlpha(165),
          Colors.black.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, bottomY, w, apronH + shadowH))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. الواجهة الأمامية الخشبية للطاولة (3D Front Apron / Skirt) لإظهار سماكة وعمق الطاولة
    final apronBl = Offset(bl.dx, bottomY + apronH);
    final apronBr = Offset(br.dx, bottomY + apronH);

    final apronPath = Path()
      ..moveTo(bl.dx, bl.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(apronBr.dx, apronBr.dy)
      ..lineTo(apronBl.dx, apronBl.dy)
      ..close();

    final apronShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF4A2814), // خشب ماهوجني مصقول في الأعلى
        Color(0xFF2C160B), // خشب جوز كلاسيكي داكن
        Color(0xFF160A04), // ظل سفلي عميق للواجهة
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(bl.dx, bottomY, br.dx - bl.dx, apronH));
    canvas.drawPath(apronPath, Paint()..shader = apronShader);

    // خط حفر ذهبي أفقي مذهب (Brass Inlay) على الواجهة الأمامية
    final goldInlayY = bottomY + apronH * 0.46;
    final goldInlayPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFFD4AF37),
          Color(0xFFFFF2A1),
          Color(0xFFD4AF37),
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.5, 0.88, 1.0],
      ).createShader(Rect.fromLTWH(bl.dx, goldInlayY, br.dx - bl.dx, 1.4))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(bl.dx + 14, goldInlayY),
      Offset(br.dx - 14, goldInlayY),
      goldInlayPaint,
    );

    // شطفة الحافة السفلية للواجهة
    final apronBottomBevel = Paint()
      ..color = const Color(0xFF0F0603)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(apronBl, apronBr, apronBottomBevel);

    // 3. الجوانب ثلاثية الأبعاد (Side Chamfers / Facets)
    // الجانب الأيسر
    final leftSidePath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(bl.dx, bl.dy)
      ..lineTo(apronBl.dx, apronBl.dy)
      ..lineTo(tl.dx, tl.dy)
      ..close();
    final leftSidePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF381B0D), Color(0xFF1E0E06)],
      ).createShader(leftSidePath.getBounds());
    canvas.drawPath(leftSidePath, leftSidePaint);

    // الجانب الأيمن (مظلل بشكل أعمق للواقعية)
    final rightSidePath = Path()
      ..moveTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(apronBr.dx, apronBr.dy)
      ..lineTo(tr.dx, tr.dy)
      ..close();
    final rightSidePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF281207), Color(0xFF120803)],
      ).createShader(rightSidePath.getBounds());
    canvas.drawPath(rightSidePath, rightSidePaint);

    // 4. إطار الخشب العلوي المصقول (Outer Wood Rail Rim)
    final topSurfacePath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final woodRimShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF3E2212),
        Color(0xFF24130A),
        Color(0xFF331B0E),
      ],
    ).createShader(topSurfacePath.getBounds());
    canvas.drawPath(topSurfacePath, Paint()..shader = woodRimShader);

    // الإطار الذهبي المحيط بالسطح
    final goldRimPaint = Paint()
      ..color = isWinnerActive
          ? AppColors.goldLight
          : AppColors.gold.withAlpha(160)
      ..strokeWidth = isWinnerActive ? 2.2 : 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topSurfacePath, goldRimPaint);

    // شطفة ذهبية براقة (Specular Gold Highlight) على الحافة الفاصلة بين السطح والواجهة
    final frontRimSpecular = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFFFFEE99),
          Color(0xFFFFD700),
          Color(0xFFFFEE99),
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.5, 0.88, 1.0],
      ).createShader(Rect.fromLTWH(bl.dx, bottomY - 1, br.dx - bl.dx, 2.5))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(bl, br, frontRimSpecular);

    // 5. الجوخ الزمردي الكازينو الفاخر (Inner Casino Emerald Felt)
    const feltInset = 9.0;
    final feltTl = Offset(tl.dx + feltInset * 0.9, tl.dy + feltInset * 0.8);
    final feltTr = Offset(tr.dx - feltInset * 0.9, tr.dy + feltInset * 0.8);
    final feltBr = Offset(br.dx - feltInset, br.dy - feltInset * 0.8);
    final feltBl = Offset(bl.dx + feltInset, bl.dy - feltInset * 0.8);

    final feltPath = Path()
      ..moveTo(feltTl.dx, feltTl.dy)
      ..lineTo(feltTr.dx, feltTr.dy)
      ..lineTo(feltBr.dx, feltBr.dy)
      ..lineTo(feltBl.dx, feltBl.dy)
      ..close();

    final feltBounds = feltPath.getBounds();
    final feltShader = RadialGradient(
      center: const Alignment(0.0, -0.06),
      radius: 0.96,
      colors: const [
        Color(0xFF106044), // زمردي كازينو حيوي ومضيء في المركز
        Color(0xFF093E2B), // زمردي مخملي فاخر
        Color(0xFF042116), // أطراف الجوخ العميقة
      ],
      stops: const [0.0, 0.58, 1.0],
    ).createShader(feltBounds);

    canvas.drawPath(feltPath, Paint()..shader = feltShader);

    // ظل داخلي تحت حافة الخشب لإبراز العمق ثلاثي الأبعاد
    final feltInnerShadow = Paint()
      ..color = Colors.black.withAlpha(85)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(feltPath, feltInnerShadow);

    // 6. خياطة ذهبية ملكية مزدوجة داخل الجوخ (Double Arabesque Stitching)
    const stitchInset = 4.5;
    final stitchPath = Path()
      ..moveTo(feltTl.dx + stitchInset * 0.9, feltTl.dy + stitchInset * 0.8)
      ..lineTo(feltTr.dx - stitchInset * 0.9, feltTr.dy + stitchInset * 0.8)
      ..lineTo(feltBr.dx - stitchInset, feltBr.dy - stitchInset * 0.8)
      ..lineTo(feltBl.dx + stitchInset, feltBl.dy - stitchInset * 0.8)
      ..close();

    final stitchPaint = Paint()
      ..color = AppColors.gold.withAlpha(45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(stitchPath, stitchPaint);

    // 7. النجمة الثمانية والزخرفة الإسلامية المركزية المائلة بالمنظور ثلاثي الأبعاد
    final cx = feltBounds.center.dx;
    final cy = feltBounds.center.dy;
    final minFeltDim = min(feltBounds.width, feltBounds.height);
    final r = minFeltDim * (isLandscape ? 0.22 : 0.25);

    final starPaint = Paint()
      ..color = AppColors.gold.withAlpha(28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final filigreePaint = Paint()
      ..color = AppColors.goldLight.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var k = 0; k < 2; k++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(k * pi / 4);
      canvas.scale(1.0, 0.84); // ضغط ثلاثي الأبعاد ليطابق ميل المنظور
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r, height: r),
        starPaint,
      );
      canvas.restore();
    }

    final ovalR1 = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 1.64,
      height: r * 1.64 * 0.84,
    );
    canvas.drawOval(ovalR1, filigreePaint);
    final ovalR2 = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 1.16,
      height: r * 1.16 * 0.84,
    );
    canvas.drawOval(ovalR2, starPaint);

    final petalPaint = Paint()
      ..color = AppColors.gold.withAlpha(22)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final px = cx + cos(angle) * (r * 0.45);
      final py = cy + sin(angle) * (r * 0.45 * 0.84);
      canvas.drawCircle(Offset(px, py), 1.8, petalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant Diwaniya3DTablePainter oldDelegate) =>
      oldDelegate.isLandscape != isLandscape ||
      oldDelegate.isWinnerActive != isWinnerActive;
}

// ============================================================================
// 2. ساحة اللعب الوسطية ثلاثية الأبعاد (TrickArena)
// ============================================================================
class TrickArena extends StatelessWidget {
  const TrickArena({
    super.key,
    required this.state,
    required this.me,
  });

  final GameState state;
  final int me;

  int _rel(int seat) => (seat - me + 4) % 4;

  static Alignment _cardAlignment(int rel, {bool isLandscape = false}) {
    if (isLandscape) {
      switch (rel) {
        case 0:
          return const Alignment(0.0, 0.58); // أنت (South)
        case 1:
          return const Alignment(0.44, -0.02); // الخصم الأيمن (East)
        case 2:
          return const Alignment(0.0, -0.62); // الشريك (North)
        default:
          return const Alignment(-0.44, -0.02); // الخصم الأيسر (West)
      }
    }
    switch (rel) {
      case 0:
        return const Alignment(0.0, 0.50); // أنت (South)
      case 1:
        return const Alignment(0.42, -0.02); // الخصم الأيمن (East)
      case 2:
        return const Alignment(0.0, -0.54); // الشريك (North)
      default:
        return const Alignment(-0.42, -0.02); // الخصم الأيسر (West)
    }
  }

  static Offset _alignmentOffset(
    Alignment a,
    double arenaW,
    double arenaH,
    double cardW,
    double cardH,
  ) {
    return Offset(
      a.x * max(0.0, arenaW - cardW) * 0.5,
      a.y * max(0.0, arenaH - cardH) * 0.5,
    );
  }

  static Offset _winnerEdgeOffset(int rel, double arenaW, double arenaH) {
    switch (rel) {
      case 0:
        return Offset(0, arenaH * 0.56 + 36); // أنت (أسفل)
      case 1:
        return Offset(arenaW * 0.54 + 48, 0); // الخصم الأيمن
      case 2:
        return Offset(0, -(arenaH * 0.56 + 36)); // الشريك (أعلى)
      default:
        return Offset(-(arenaW * 0.54 + 48), 0); // الخصم الأيسر
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final winner = s.trick.isComplete && s.trump != null
        ? Rules.trickWinner(s.trick, s.trump!)
        : null;
    final leading = s.trick.plays.length >= 2 && s.trump != null
        ? Rules.trickWinner(s.trick, s.trump!)
        : null;
    final lt = Rules.teamOf(me);
    final ourTricks = s.tricksWon[lt];
    final oppTricks = s.tricksWon[1 - lt];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final isLandscape = maxW > maxH * 1.15;
        final arenaH = (maxH * 0.99).clamp(160.0, 460.0);
        final arenaW = isLandscape
            ? min(maxW * 0.98, arenaH * 2.25).clamp(280.0, 680.0)
            : (maxW * 0.98).clamp(210.0, 480.0);
        final cardW = isLandscape
            ? (arenaH * 0.215).clamp(40.0, 56.0)
            : min(arenaH * 0.24, arenaW * 0.21).clamp(48.0, 72.0);
        final cardH = cardW * 1.44;

        final winnerRel = winner == null ? null : _rel(winner);
        final winnerDest = winnerRel == null
            ? null
            : _winnerEdgeOffset(winnerRel, arenaW, arenaH);

        return Center(
          child: SizedBox(
            width: arenaW,
            height: arenaH,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. هيكل الطاولة ثلاثية الأبعاد الفاخرة بالكامل معزولة بـ RepaintBoundary لسرعة 60fps
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: Diwaniya3DTablePainter(
                        isLandscape: isLandscape,
                        isWinnerActive: winner != null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // إضاءة الدور (Turn Spotlight) نحو اللاعب الحالي على سطح الجوخ
                          if (s.actor != null &&
                              (s.phase == GamePhase.playing ||
                                  s.phase == GamePhase.bidding))
                            AnimatedAlign(
                              key: const ValueKey('turn_spotlight'),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              alignment: _cardAlignment(
                                _rel(s.actor!),
                                isLandscape: isLandscape,
                              ),
                              child: Container(
                                width: cardW * 1.85,
                                height: cardH * 1.35,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.gold.withAlpha(48),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // رزم الأكلات المكتسبة على زوايا الطاولة
                          if (ourTricks > 0)
                            Positioned(
                              key: const ValueKey('our_trick_stack'),
                              left: isLandscape ? 24 : 18,
                              bottom: isLandscape ? 34 : 26,
                              child: _TeamTrickStack(
                                count: ourTricks,
                                isOurTeam: true,
                                onTap: s.lastTrick.isEmpty
                                    ? null
                                    : () => showLastTrickDialog(context, s),
                              ),
                            ),
                          if (oppTricks > 0)
                            Positioned(
                              key: const ValueKey('opp_trick_stack'),
                              right: isLandscape ? 24 : 18,
                              top: isLandscape ? 16 : 12,
                              child: _TeamTrickStack(
                                count: oppTricks,
                                isOurTeam: false,
                                onTap: s.lastTrick.isEmpty
                                    ? null
                                    : () => showLastTrickDialog(context, s),
                              ),
                            ),

                          // الختم المركزي المذهب للحكم
                          AnimatedSwitcher(
                            key: const ValueKey('trump_badge'),
                            duration: const Duration(milliseconds: 380),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutBack,
                              ),
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                            child: s.trump != null
                                ? Container(
                                    key: ValueKey(
                                        'trump_${s.trump}_${s.roundNumber}'),
                                    width: isLandscape ? 40 : 46,
                                    height: isLandscape ? 40 : 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        center: Alignment(-0.28, -0.32),
                                        colors: [
                                          Color(0xFFFFF6B8),
                                          Color(0xFFE5B83A),
                                          Color(0xFF9E720F),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: AppColors.goldLight,
                                        width: 1.6,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(160),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                        BoxShadow(
                                          color: AppColors.gold.withAlpha(120),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: isLandscape ? 30 : 34,
                                      height: isLandscape ? 30 : 34,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF041B12),
                                      ),
                                      alignment: Alignment.center,
                                      child: SuitIcon(
                                        suit: s.trump!,
                                        size: isLandscape ? 17 : 20,
                                        color: s.trump!.isRed
                                            ? const Color(0xFFFF5252)
                                            : AppColors.goldLight,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. حركة توزيع الكروت المتسلسلة فوق الطاولة
                if (s.roundNumber > 0)
                  _DealDeckBurst(
                    key: ValueKey('deal_burst_${s.roundNumber}'),
                    dealer: s.dealer,
                    me: me,
                    cardWidth: cardW,
                    arenaWidth: arenaW,
                    arenaHeight: arenaH,
                  ),

                // 3. كروت اللمة (Trick plays) مستقرة على سطح الطاولة ثلاثية الأبعاد
                for (final p in s.trick.plays)
                  Builder(
                    key: ValueKey('slot_${p.card}-${p.player}'),
                    builder: (_) {
                      final rel = _rel(p.player);
                      final align =
                          _cardAlignment(rel, isLandscape: isLandscape);
                      final seatOffset = _alignmentOffset(
                        align,
                        arenaW - 14,
                        arenaH - 14,
                        cardW,
                        cardH,
                      );
                      return Align(
                        alignment: align,
                        child: _PlayedCard(
                          key: ValueKey('${p.card}-${p.player}'),
                          rel: rel,
                          card: p.card,
                          cardWidth: cardW,
                          isWinner: winner == p.player || leading == p.player,
                          sweepRel: winnerRel,
                          seatOffset: seatOffset,
                          sweepTarget: winnerDest,
                        ),
                      );
                    },
                  ),

                // 4. شارة الفائز باللمة تظهر بعد استقرار الورقة الرابعة
                if (winner != null)
                  _TrickWinnerBadge(
                    key: ValueKey(
                      'win_${s.trick.plays.length}_${s.tricksWon[0]}_${s.tricksWon[1]}_$winner',
                    ),
                    sameTeam: Rules.teamOf(winner) == Rules.teamOf(me),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 3. توزيع احترافي متسلسل لاعب تلو الآخر
// ============================================================================
class _DealDeckBurst extends StatefulWidget {
  const _DealDeckBurst({
    super.key,
    required this.dealer,
    required this.me,
    required this.cardWidth,
    required this.arenaWidth,
    required this.arenaHeight,
  });

  final int dealer;
  final int me;
  final double cardWidth;
  final double arenaWidth;
  final double arenaHeight;

  @override
  State<_DealDeckBurst> createState() => _DealDeckBurstState();
}

class _DealDeckBurstState extends State<_DealDeckBurst>
    with SingleTickerProviderStateMixin {
  late Widget _deckBack = _buildDeckBack();
  late Widget _flyingBack = _buildFlyingBack();
  late Widget _edgeBase = _buildEdgeCard(shadow: true, light: true);
  late Widget _edgeLight = _buildEdgeCard(shadow: false, light: true);
  late Widget _edgeDark = _buildEdgeCard(shadow: false, light: false);

  double get _deckW => (widget.cardWidth * 1.14).clamp(54.0, 76.0);
  double get _deckH => _deckW * 1.44;

  Widget _buildDeckBack() => CardBackView(width: _deckW);

  Widget _buildFlyingBack() {
    final flyW = (widget.cardWidth * 0.92).clamp(44.0, 62.0);
    return CardBackView(width: flyW);
  }

  Widget _buildEdgeCard({required bool shadow, required bool light}) {
    return RepaintBoundary(
      child: Container(
        width: _deckW,
        height: _deckH,
        decoration: BoxDecoration(
          color: light ? const Color(0xFFF3ECE0) : const Color(0xFFDAD0BE),
          borderRadius: BorderRadius.circular(_deckW * 0.13),
          border: Border.all(
            color: Colors.black.withAlpha(55),
            width: 0.7,
          ),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 12,
                    offset: const Offset(2, 6),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  );
  int _lastSoundStage = -1;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant _DealDeckBurst old) {
    super.didUpdateWidget(old);
    if ((old.cardWidth - widget.cardWidth).abs() > 0.5) {
      _deckBack = _buildDeckBack();
      _flyingBack = _buildFlyingBack();
      _edgeBase = _buildEdgeCard(shadow: true, light: true);
      _edgeLight = _buildEdgeCard(shadow: false, light: true);
      _edgeDark = _buildEdgeCard(shadow: false, light: false);
    }
  }

  void _onTick() {
    final stage = (_c.value * 4).floor().clamp(0, 3);
    if (stage != _lastSoundStage && _c.value < 0.96) {
      _lastSoundStage = stage;
      SoundService.instance.play(Sfx.deal);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  int _rel(int seat) => (seat - widget.me + 4) % 4;

  (Offset, double) _targetForRel(int rel) {
    final dx = widget.arenaWidth * 0.54 + 26;
    final dy = widget.arenaHeight * 0.54 + 26;
    switch (rel) {
      case 1:
        return (Offset(dx, 0), -0.35); // الخصم الأيمن
      case 2:
        return (Offset(0, -dy), 0.12); // الشريك (أعلى)
      case 3:
        return (Offset(-dx, 0), 0.35); // الخصم الأيسر
      default:
        return (Offset(0, dy), 0.0); // أنت (أسفل)
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckW = (widget.cardWidth * 1.14).clamp(54.0, 76.0);
    final deckH = deckW * 1.44;
    final glowSize = deckH * 1.15;

    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            if (v >= 0.99) return const SizedBox.shrink();

            final deckRemaining = (9 * (1.0 - v)).ceil().clamp(0, 9);
            final seatsInOrder = [
              for (var order = 0; order < 4; order++)
                (widget.dealer + 1 + order) % 4,
            ];

            final deckFadeScale = v > 0.88
                ? (1.0 - ((v - 0.88) / 0.12) * 0.45).clamp(0.55, 1.0)
                : 1.0;

            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: (1.0 - v * 0.35).clamp(0.45, 1.0),
                  child: Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withAlpha(
                              ((1.0 - v) * 62).round().clamp(0, 80)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                for (var s = 0; s < deckRemaining - 1; s++)
                  Transform.translate(
                    offset: Offset(-s * 1.25, -s * 1.5),
                    child: deckFadeScale < 0.99
                        ? Transform.scale(
                            scale: deckFadeScale,
                            child: s == 0
                                ? _edgeBase
                                : (s.isEven ? _edgeLight : _edgeDark),
                          )
                        : (s == 0
                            ? _edgeBase
                            : (s.isEven ? _edgeLight : _edgeDark)),
                  ),
                if (deckRemaining > 0)
                  Transform.translate(
                    offset: Offset(
                      -(deckRemaining - 1) * 1.25,
                      -(deckRemaining - 1) * 1.5,
                    ),
                    child: deckFadeScale < 0.99
                        ? Transform.scale(
                            scale: deckFadeScale, child: _deckBack)
                        : _deckBack,
                  ),
                for (var order = 0; order < 4; order++)
                  if (_rel(seatsInOrder[order]) != 0)
                    for (var cardIdx = 0; cardIdx < 5; cardIdx++)
                      _flyingPlayerCard(
                        v: v,
                        start: order * 0.21 + cardIdx * 0.030,
                        span: 0.16,
                        target: _targetForRel(_rel(seatsInOrder[order])).$1,
                        spin: _targetForRel(_rel(seatsInOrder[order])).$2,
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _flyingPlayerCard({
    required double v,
    required double start,
    required double span,
    required Offset target,
    required double spin,
  }) {
    final local = ((v - start) / span).clamp(0.0, 1.0);
    if (local <= 0.0 || local >= 1.0) return const SizedBox.shrink();
    final t = Curves.easeOutQuart.transform(local);
    final arc = sin(local * pi) * 18.0;
    final popScale = local < 0.14
        ? (0.58 + 0.42 * (local / 0.14))
        : (local > 0.80 ? (1.0 - (local - 0.80) / 0.20 * 0.35) : 1.0);
    return Transform.translate(
      offset: Offset(target.dx * t, target.dy * t - arc),
      child: Transform.scale(
        scale: (1.0 - 0.22 * t) * popScale,
        child: Transform.rotate(
          angle: spin * t,
          child: _flyingBack,
        ),
      ),
    );
  }
}

// ============================================================================
// 4. شارة الفائز باللمة
// ============================================================================
class _TrickWinnerBadge extends StatelessWidget {
  const _TrickWinnerBadge({super.key, required this.sameTeam});

  final bool sameTeam;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1180),
        curve: Curves.linear,
        builder: (context, t, child) {
          if (t < 0.25) return const SizedBox.shrink();
          final local = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
          final pop =
              Curves.easeOutBack.transform((local * 2.4).clamp(0.0, 1.0));
          final fade = local < 0.72
              ? 1.0
              : (1.0 - (local - 0.72) / 0.28).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, -14 * local),
            child: Transform.scale(
              scale: pop,
              child: fade < 0.99 ? Opacity(opacity: fade, child: child) : child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: sameTeam
                  ? const [AppColors.goldLight, AppColors.gold]
                  : const [Color(0xFFE05244), Color(0xFF9E2A20)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
          ),
          child: Text(
            sameTeam ? '+1 لنا' : '+1 لهم',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: sameTeam ? const Color(0xFF1E1304) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. ورقة على سطح الطاولة ثلاثية الأبعاد
// ============================================================================
class _PlayedCard extends StatefulWidget {
  const _PlayedCard({
    super.key,
    required this.rel,
    required this.card,
    required this.cardWidth,
    required this.isWinner,
    required this.sweepRel,
    required this.seatOffset,
    required this.sweepTarget,
  });

  final int rel;
  final PlayingCard card;
  final double cardWidth;
  final bool isWinner;
  final int? sweepRel;
  final Offset seatOffset;
  final Offset? sweepTarget;

  @override
  State<_PlayedCard> createState() => _PlayedCardState();
}

class _PlayedCardState extends State<_PlayedCard>
    with TickerProviderStateMixin {
  static const _from = [
    Offset(0, 150),
    Offset(210, 0),
    Offset(0, -140),
    Offset(-210, 0),
  ];
  static const _restAngle = [0.0, 0.09, -0.04, -0.09];

  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280))
    ..forward();
  late final AnimationController _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _sweepTimer;

  @override
  void initState() {
    super.initState();
    if (widget.sweepRel != null) _scheduleSweep();
  }

  @override
  void didUpdateWidget(covariant _PlayedCard old) {
    super.didUpdateWidget(old);
    if (old.sweepRel == null && widget.sweepRel != null) _scheduleSweep();
  }

  void _scheduleSweep() {
    _sweepTimer?.cancel();
    _sweepTimer = Timer(const Duration(milliseconds: 820), () {
      if (mounted) _sweep.forward();
    });
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    _enter.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _sweep]),
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        final swRaw = _sweep.value;
        final gatherT =
            Curves.easeOutCubic.transform((swRaw / 0.42).clamp(0.0, 1.0));
        final flyOutT = Curves.easeInCubic
            .transform(((swRaw - 0.36) / 0.64).clamp(0.0, 1.0));

        final o = _from[widget.rel];
        final stackFan = Offset(
          (widget.rel - 1.5) * 3.0,
          (widget.rel - 1.5) * 1.5,
        );

        var dx = o.dx * (1 - t) +
            (-widget.seatOffset.dx + stackFan.dx) * gatherT;
        var dy = o.dy * (1 - t) -
            sin(t * pi) * 18 +
            (-widget.seatOffset.dy + stackFan.dy) * gatherT;

        final dest = widget.sweepTarget;
        if (dest != null && flyOutT > 0.0) {
          dx += dest.dx * flyOutT;
          dy += dest.dy * flyOutT - sin(flyOutT * pi) * 16;
        }

        final enterScale = 1.18 - 0.18 * t;
        final winnerPop =
            widget.isWinner ? (1.0 + 0.08 * sin(_enter.value * pi)) : 1.0;
        final sweepScale = flyOutT < 0.78
            ? (1.0 - 0.50 * flyOutT)
            : (0.61 - 0.46 * ((flyOutT - 0.78) / 0.22)).clamp(0.14, 1.0);
        final tiltX = (1 - t) * 0.36 + 0.08 * t; // ميل ثلاثي الأبعاد دائم على سطح الطاولة
        final gatherAngle = _restAngle[widget.rel] * (1 - gatherT) +
            (widget.rel - 1.5) * 0.05 * gatherT;
        final sweepOpacity = flyOutT < 0.82
            ? 1.0
            : (1.0 - (flyOutT - 0.82) / 0.18).clamp(0.0, 1.0);

        final rotatedChild = Transform.rotate(
          angle: gatherAngle * t + (1 - t) * 0.22 + 0.18 * flyOutT,
          child: sweepOpacity < 0.99
              ? Opacity(opacity: sweepOpacity, child: child)
              : child,
        );

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: enterScale * winnerPop * sweepScale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(tiltX),
              child: rotatedChild,
            ),
          ),
        );
      },
      child: PlayingCardView(
        card: widget.card,
        width: widget.cardWidth,
        highlighted: widget.isWinner,
      ),
    );
  }
}

// ============================================================================
// 6. رزم أكلات الفريق المكتسبة
// ============================================================================
class _TeamTrickStack extends StatelessWidget {
  const _TeamTrickStack({
    required this.count,
    required this.isOurTeam,
    this.onTap,
  });

  final int count;
  final bool isOurTeam;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = min(count, 4);
    final accent =
        isOurTeam ? const Color(0xFF34C992) : const Color(0xFFE06D44);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24 + (visible - 1) * 3.0,
            height: 34,
            child: Stack(
              children: [
                for (var i = 0; i < visible; i++)
                  Positioned(
                    left: i * 3.0,
                    top: (visible - 1 - i) * 1.0,
                    child: const CardBackView(width: 22),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withAlpha(150), width: 1.0),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. نافذة مصغرة لآخر أكلة
// ============================================================================
class MiniLastTrickBox extends StatelessWidget {
  const MiniLastTrickBox({
    super.key,
    required this.state,
    required this.me,
  });

  final GameState state;
  final int me;

  int _rel(int seat) => (seat - me + 4) % 4;

  static Alignment _align(int rel) {
    switch (rel) {
      case 0:
        return const Alignment(0.0, 0.85);
      case 1:
        return const Alignment(0.85, 0.0);
      case 2:
        return const Alignment(0.0, -0.85);
      default:
        return const Alignment(-0.85, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plays = state.lastTrick;
    if (plays.isEmpty) return const SizedBox.shrink();
    final winner = state.lastTrickWinner;

    return GestureDetector(
      onTap: () => showLastTrickDialog(context, state),
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xF207241A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gold.withAlpha(160),
            width: 1.2,
          ),
          boxShadow: [
            const BoxShadow(
                color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
            BoxShadow(color: AppColors.gold.withAlpha(45), blurRadius: 6),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final p in plays)
              Align(
                alignment: _align(_rel(p.player)),
                child: PlayingCardView(
                  card: p.card,
                  width: 15,
                  highlighted: p.player == winner,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
