import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/card.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import 'game_hud.dart';

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
          return const Alignment(0.0, 0.86); // أنت (South)
        case 1:
          return const Alignment(0.70, 0.0); // الخصم الأيمن (East)
        case 2:
          return const Alignment(0.0, -0.86); // الشريك (North)
        default:
          return const Alignment(-0.70, 0.0); // الخصم الأيسر (West)
      }
    }
    switch (rel) {
      case 0:
        return const Alignment(0.0, 0.68); // أنت (South)
      case 1:
        return const Alignment(0.68, 0.0); // الخصم الأيمن (East)
      case 2:
        return const Alignment(0.0, -0.68); // الشريك (North)
      default:
        return const Alignment(-0.68, 0.0); // الخصم الأيسر (West)
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
        return Offset(0, arenaH * 0.58 + 38); // أنت (أسفل)
      case 1:
        return Offset(arenaW * 0.54 + 48, 0); // الخصم الأيمن
      case 2:
        return Offset(0, -(arenaH * 0.58 + 38)); // الشريك (أعلى)
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
        final outerRadius = isLandscape
            ? min(30.0, arenaH * 0.14)
            : min(38.0, min(arenaH, arenaW) * 0.16);
        final innerRadius = max(14.0, outerRadius - 7);
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
                // الإطار الخشبي + الجوخ المقصوص بالزوايا الدائرية
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(outerRadius),
                      // حافة الطاولة المصقولة ثلاثية الأبعاد (خشب الجوز الملكي مع الإطار الذهبي)
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4B2B17),
                          Color(0xFF2B160B),
                          Color(0xFF1B0D06),
                          Color(0xFF3D2111),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: winner != null
                            ? AppColors.goldLight
                            : AppColors.gold.withAlpha(140),
                        width: winner != null ? 2.0 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(210),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 10),
                        ),
                        if (winner != null)
                          BoxShadow(
                            color: AppColors.gold.withAlpha(70),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(innerRadius),
                        border: Border.all(
                          color: AppColors.gold.withAlpha(65),
                          width: 1.2,
                        ),
                        // سطح جوخ كويتي زمردي-تركواز هادئ ومريح للعين كما في الألعاب العالمية
                        gradient: const RadialGradient(
                          center: Alignment(0.0, -0.06),
                          radius: 0.95,
                          colors: [
                            Color(0xFF237A68),
                            Color(0xFF17584A),
                            Color(0xFF0E3B31),
                          ],
                          stops: [0.0, 0.58, 1.0],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(max(12.0, innerRadius - 2)),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // زخرفة وسط الطاولة الهادئة مع عزل الرسم في طبقة منفصلة لسرعة الأداء
                            const Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(painter: _TableSurfacePainter()),
                              ),
                            ),

                            // ظل داخلي ناعم تحت حافة الطاولة لإبراز العمق ثلاثي الأبعاد
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      max(12.0, innerRadius - 2),
                                    ),
                                    border: Border.all(
                                      color: Colors.black.withAlpha(90),
                                      width: 3.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // إضاءة الدور (Turn Spotlight) نحو اللاعب الحالي
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

                            // رزم الأكلات المكتسبة لكل فريق على الطاولة (بالضغط عليها تعرض آخر أكلة)
                            if (ourTricks > 0)
                              Positioned(
                                key: const ValueKey('our_trick_stack'),
                                left: isLandscape ? 18 : 14,
                                bottom: 10,
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
                                right: isLandscape ? 18 : 14,
                                top: 10,
                                child: _TeamTrickStack(
                                  count: oppTricks,
                                  isOurTeam: false,
                                  onTap: s.lastTrick.isEmpty
                                      ? null
                                      : () => showLastTrickDialog(context, s),
                                ),
                              ),

                            // الختم المركزي للحكم
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
                                      key: ValueKey('trump_${s.trump}_${s.roundNumber}'),
                                      width: isLandscape ? 38 : 44,
                                      height: isLandscape ? 38 : 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xD8041B12),
                                        border: Border.all(
                                          color: AppColors.gold.withAlpha(175),
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.gold.withAlpha(60),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        s.trump!.symbol,
                                        style: TextStyle(
                                          fontSize: isLandscape ? 19 : 22,
                                          height: 1,
                                          color: s.trump!.isRed
                                              ? const Color(0xFFFF6B6B)
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
                ),

                // طبقة حركة الورق فوق الطاولة بدون قصّ (Clip.none) حتى تظهر الورقة الرابعة أثناء دخولها وسحب الأكلة
                if (s.roundNumber > 0)
                  _DealDeckBurst(
                    key: ValueKey('deal_burst_${s.roundNumber}'),
                    dealer: s.dealer,
                    me: me,
                    cardWidth: cardW,
                    arenaWidth: arenaW,
                    arenaHeight: arenaH,
                  ),

                for (final p in s.trick.plays)
                  Builder(
                    key: ValueKey('slot_${p.card}-${p.player}'),
                    builder: (_) {
                      final rel = _rel(p.player);
                      final align = _cardAlignment(rel, isLandscape: isLandscape);
                      final seatOffset = _alignmentOffset(
                        align,
                        arenaW - 14,
                        arenaH - 14,
                        cardW,
                        cardH,
                      );
                      return Padding(
                        padding: const EdgeInsets.all(7),
                        child: Align(
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
                        ),
                      );
                    },
                  ),

                // شارة الفائز باللمة تظهر بعد نزول الورقة الرابعة واستقرارها
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

/// توزيع احترافي متسلسل لاعب تلو الآخر (عكس عقارب الساعة بدءاً من يمين الموزع).
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

  Widget _buildDeckBack() {
    final deckW = (widget.cardWidth * 1.14).clamp(54.0, 76.0);
    return CardBackView(width: deckW);
  }

  Widget _buildFlyingBack() {
    final flyW = (widget.cardWidth * 0.92).clamp(44.0, 62.0);
    return CardBackView(width: flyW);
  }

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
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
            // ترتيب التوزيع: 4 لاعبين بالتتابع، كل لاعب له نافذة زمنية مخصصة (0.25 من الوقت)
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
                // هالة ذهبية وظل ناعم تحت رزمة الكوتشينة الوسطية
                Transform.scale(
                  scale: (1.0 - v * 0.35).clamp(0.45, 1.0),
                  child: Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withAlpha(((1.0 - v) * 62).round().clamp(0, 80)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // طبقات سمك الكوتشينة (الحافة الورقية السفلية) ثم الوجه العلوي الفاخر
                for (var s = 0; s < deckRemaining - 1; s++)
                  Transform.translate(
                    offset: Offset(-s * 1.25, -s * 1.5),
                    child: Transform.scale(
                      scale: deckFadeScale,
                      child: Container(
                        width: deckW,
                        height: deckH,
                        decoration: BoxDecoration(
                          color: s.isEven
                              ? const Color(0xFFF3ECE0)
                              : const Color(0xFFDAD0BE),
                          borderRadius: BorderRadius.circular(deckW * 0.13),
                          border: Border.all(
                            color: Colors.black.withAlpha(55),
                            width: 0.7,
                          ),
                          boxShadow: s == 0
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
                    ),
                  ),
                if (deckRemaining > 0)
                  Transform.translate(
                    offset: Offset(
                      -(deckRemaining - 1) * 1.25,
                      -(deckRemaining - 1) * 1.5,
                    ),
                    child: deckFadeScale < 0.99
                        ? Transform.scale(scale: deckFadeScale, child: _deckBack)
                        : _deckBack,
                  ),
                // توزيع الأوراق لاعب تلو الآخر (لا يطير ورق للاعب الثاني قبل انتهاء الأول)
                for (var order = 0; order < 4; order++)
                  if (_rel(seatsInOrder[order]) != 0)
                    for (var cardIdx = 0; cardIdx < 5; cardIdx++)
                      _flyingPlayerCard(
                        v: v,
                        start: order * 0.24 + cardIdx * 0.032,
                        span: 0.085,
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
    final t = Curves.easeOutCubic.transform(local);
    final arc = sin(local * pi) * 18.0;
    // استبدال Opacity بتلاشي الحجم في البداية والنهاية لتفادي saveLayer وضمان 60fps
    final popScale = local < 0.14
        ? (0.55 + 0.45 * (local / 0.14))
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
          // تنتظر الشارة حتى تنزل الورقة الرابعة وتستقر على الطاولة أولاً
          if (t < 0.25) return const SizedBox.shrink();
          final local = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
          final pop = Curves.easeOutBack.transform((local * 2.4).clamp(0.0, 1.0));
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

/// ورقة على الطاولة: تنطلق بميل ثلاثي الأبعاد وقوس واقعي، وعند اكتمال الـ 4 أوراق تستقر جميعها معاً ثم تتجمع وتطير للفائز.
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

class _PlayedCardState extends State<_PlayedCard> with TickerProviderStateMixin {
  static const _from = [
    Offset(0, 150),
    Offset(210, 0),
    Offset(0, -140),
    Offset(-210, 0),
  ];
  static const _restAngle = [0.0, 0.09, -0.04, -0.09];

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280))
        ..forward();
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
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
    // مهلة واضحة (820ms): تنزل الورقة الرابعة (280ms) وتظل الـ 4 أوراق ظاهرة معاً (540ms) قبل السحب
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
        // المرحلة 1: تجميع الأوراق الأربع في منتصف الطاولة تماماً فوق بعضها (0.0 -> 0.42)
        final gatherT = Curves.easeOutCubic.transform((swRaw / 0.42).clamp(0.0, 1.0));
        // المرحلة 2: طيران الكومة المجمّعة معاً دفعة واحدة نحو الفائز (0.36 -> 1.0)
        final flyOutT = Curves.easeInCubic.transform(((swRaw - 0.36) / 0.64).clamp(0.0, 1.0));

        final o = _from[widget.rel];
        final stackFan = Offset(
          (widget.rel - 1.5) * 3.0,
          (widget.rel - 1.5) * 1.5,
        );

        var dx = o.dx * (1 - t) + (-widget.seatOffset.dx + stackFan.dx) * gatherT;
        var dy = o.dy * (1 - t) -
            sin(t * pi) * 18 +
            (-widget.seatOffset.dy + stackFan.dy) * gatherT;

        final dest = widget.sweepTarget;
        if (dest != null && flyOutT > 0.0) {
          dx += dest.dx * flyOutT;
          dy += dest.dy * flyOutT - sin(flyOutT * pi) * 16;
        }

        final enterScale = 1.20 - 0.20 * t;
        final winnerPop = widget.isWinner ? (1.0 + 0.08 * sin(_enter.value * pi)) : 1.0;
        final sweepScale = 1.0 - 0.54 * flyOutT;
        final tiltX = (1 - t) * 0.40;
        final gatherAngle = _restAngle[widget.rel] * (1 - gatherT) +
            (widget.rel - 1.5) * 0.05 * gatherT;
        final sweepOpacity = flyOutT < 0.76
            ? 1.0
            : (1.0 - (flyOutT - 0.76) / 0.24).clamp(0.0, 1.0);

        final enterOp = (t * 5.0).clamp(0.0, 1.0);
        final totalOpacity = (enterOp * sweepOpacity).clamp(0.0, 1.0).toDouble();
        final rotatedChild = Transform.rotate(
          angle: gatherAngle * t + (1 - t) * 0.24 + 0.18 * flyOutT,
          child: totalOpacity < 0.99
              ? Opacity(opacity: totalOpacity, child: child)
              : child,
        );

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: enterScale * winnerPop * sweepScale,
            child: tiltX > 0.002
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateX(tiltX),
                    child: rotatedChild,
                  )
                : rotatedChild,
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
    final accent = isOurTeam ? const Color(0xFF34C992) : const Color(0xFFE06D44);
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

/// نافذة مصغرة في زاوية الشاشة تعرض آخر 4 أوراق نزلت بوضعية (شمال/جنوب/شرق/غرب) كما في الألعاب العالمية.
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
          color: const Color(0xCC071622),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gold.withAlpha(115),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
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

class _TableSurfacePainter extends CustomPainter {
  const _TableSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final minDim = min(size.width, size.height);
    final isLandscape = size.width > size.height * 1.15;

    // 1. خط ذهبي داخلي رفيع وهادئ يتبع انحناء الطاولة
    final outerStitch = Paint()
      ..color = AppColors.gold.withAlpha(42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rOuter = isLandscape
        ? min(22.0, size.height * 0.12)
        : max(12.0, min(30.0, minDim * 0.15));
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rOuter)),
      outerStitch,
    );

    // 2. ميدالية وسطية هادئة (النجمة الثمانية الكويتية) بحجم متناسق مع الطولي والعرضي
    final r = minDim * (isLandscape ? 0.22 : 0.24);
    final starPaint = Paint()
      ..color = AppColors.gold.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

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
    canvas.drawCircle(Offset(cx, cy), r * 0.78, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
