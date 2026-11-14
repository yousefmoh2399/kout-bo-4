import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../bloc/game_bloc.dart';
import '../../core/theme.dart';
import '../../domain/card.dart';
import '../../domain/rules.dart';
import '../card_view.dart';

class TrickArena extends StatelessWidget {
  const TrickArena({
    super.key,
    required this.state,
    required this.me,
  });

  final GameState state;
  final int me;

  int _rel(int seat) => (seat - me + 4) % 4;

  static Alignment _cardAlignment(int rel) {
    switch (rel) {
      case 0:
        return const Alignment(0.0, 0.64); // أنت (South)
      case 1:
        return const Alignment(0.64, 0.0); // الخصم الأيمن (East)
      case 2:
        return const Alignment(0.0, -0.64); // الشريك (North)
      default:
        return const Alignment(-0.64, 0.0); // الخصم الأيسر (West)
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
        final arenaH = (maxH * 0.98).clamp(165.0, 410.0);
        final arenaW = min(maxW * 0.97, arenaH * 1.65);
        final cardW = min(arenaH * 0.27, arenaW * 0.22).clamp(50.0, 76.0);
        final cardH = cardW * 1.44;

        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: arenaW,
            height: arenaH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(arenaH * 0.45),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0A432A).withAlpha(205),
                  const Color(0xFF052416).withAlpha(225),
                ],
              ),
              border: Border.all(
                color: winner != null
                    ? AppColors.gold.withAlpha(180)
                    : AppColors.gold.withAlpha(70),
                width: winner != null ? 2.0 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: winner != null
                      ? AppColors.gold.withAlpha(50)
                      : Colors.black.withAlpha(85),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // خط داخلي ذهبي مزدوج لساحة اللعب
                Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(arenaH * 0.42),
                    border: Border.all(color: AppColors.gold.withAlpha(30), width: 0.8),
                  ),
                ),

                // إضاءة الدور (Turn Spotlight) نحو اللاعب الحالي
                if (s.actor != null &&
                    (s.phase == GamePhase.playing || s.phase == GamePhase.bidding))
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: _cardAlignment(_rel(s.actor!)),
                    child: Container(
                      width: cardW * 1.9,
                      height: cardH * 1.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gold.withAlpha(36),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // رزم الأكلات المكتسبة لكل فريق على الطاولة
                if (ourTricks > 0)
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: _TeamTrickStack(
                      count: ourTricks,
                      isOurTeam: true,
                    ),
                  ),
                if (oppTricks > 0)
                  Positioned(
                    right: 14,
                    top: 12,
                    child: _TeamTrickStack(
                      count: oppTricks,
                      isOurTeam: false,
                    ),
                  ),

                // خانات نزول الورق الأربع الخفيفة (تضيء الخانة النشطة عند دور اللاعب)
                for (var rel = 0; rel < 4; rel++)
                  Align(
                    alignment: _cardAlignment(rel),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: cardW,
                      height: cardH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardW * 0.13),
                        border: Border.all(
                          color: (s.actor != null &&
                                  _rel(s.actor!) == rel &&
                                  s.phase == GamePhase.playing)
                              ? AppColors.gold.withAlpha(125)
                              : Colors.white.withAlpha(18),
                          width: (s.actor != null &&
                                  _rel(s.actor!) == rel &&
                                  s.phase == GamePhase.playing)
                              ? 1.4
                              : 1.0,
                        ),
                        color: (s.actor != null &&
                                _rel(s.actor!) == rel &&
                                s.phase == GamePhase.playing)
                            ? AppColors.gold.withAlpha(16)
                            : Colors.black.withAlpha(22),
                      ),
                    ),
                  ),

                // موجة توزيع الأوراق لجميع المقاعد عند بداية الجولة
                if (s.roundNumber > 0)
                  _DealDeckBurst(key: ValueKey('deal_burst_${s.roundNumber}')),

                // الختم المركزي للحكم مع أنيميشن نبض عند اختيار الحكم
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: s.trump != null
                      ? Container(
                          key: ValueKey('trump_${s.trump}_${s.roundNumber}'),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xD8041B12),
                            border: Border.all(
                              color: AppColors.gold.withAlpha(170),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(color: AppColors.gold.withAlpha(65), blurRadius: 12),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.trump!.symbol,
                            style: TextStyle(
                              fontSize: 23,
                              height: 1,
                              color: s.trump!.isRed
                                  ? const Color(0xFFFF6B6B)
                                  : AppColors.goldLight,
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('no_trump'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withAlpha(45),
                            border: Border.all(
                              color: AppColors.gold.withAlpha(45),
                              width: 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '♠',
                            style: TextStyle(
                              fontSize: 22,
                              color: AppColors.gold.withAlpha(65),
                              height: 1,
                            ),
                          ),
                        ),
                ),

                // الكروت الملعوبة على الطاولة بفيزياء رمي ثلاثية الأبعاد
                for (final p in s.trick.plays)
                  Align(
                    alignment: _cardAlignment(_rel(p.player)),
                    child: _PlayedCard(
                      key: ValueKey('${p.card}-${p.player}'),
                      rel: _rel(p.player),
                      card: p.card,
                      cardWidth: cardW,
                      isWinner: winner == p.player || leading == p.player,
                      sweepRel: winner == null ? null : _rel(winner),
                    ),
                  ),

                // شارة الفائز باللمة عند اكتمال الأوراق الأربع
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

class _DealDeckBurst extends StatefulWidget {
  const _DealDeckBurst({super.key});

  @override
  State<_DealDeckBurst> createState() => _DealDeckBurstState();
}

class _DealDeckBurstState extends State<_DealDeckBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          if (v >= 0.99) return const SizedBox.shrink();
          // اتجاهات اللاعبين الآخرين بالترتيب: يمين، شريك (أعلى)، يسار
          const targets = [
            (Offset(175, -8), -0.45),
            (Offset(0, -145), 0.18),
            (Offset(-175, -8), 0.45),
          ];
          final deckRemaining = (8 * (1.0 - Curves.easeIn.transform(v)))
              .ceil()
              .clamp(0, 8);

          return Stack(
            alignment: Alignment.center,
            children: [
              // هالة ذهبية خفيفة تحت كومة التوزيع
              Opacity(
                opacity: (1.0 - v).clamp(0.0, 1.0) * 0.65,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withAlpha(85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // كومة أوراق ثلاثية الأبعاد تتناقص ورقة تلو الأخرى أثناء التوزيع
              for (var s = 0; s < deckRemaining; s++)
                Transform.translate(
                  offset: Offset(-s * 1.2, -s * 1.4),
                  child: Opacity(
                    opacity: v > 0.85
                        ? ((1.0 - v) / 0.15).clamp(0.0, 1.0)
                        : 1.0,
                    child: const CardBackView(width: 40),
                  ),
                ),
              // توزيع متسلسل ورقة تلو الأخرى بعكس عقارب الساعة
              for (var wave = 0; wave < 9; wave++)
                for (var tIdx = 0; tIdx < targets.length; tIdx++)
                  _flyingCard(
                    v,
                    (wave * 3 + tIdx) * 0.0285,
                    targets[tIdx].$1,
                    targets[tIdx].$2,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _flyingCard(double v, double delay, Offset target, double spin) {
    final local = ((v - delay) / 0.19).clamp(0.0, 1.0);
    if (local <= 0.0 || local >= 1.0) return const SizedBox.shrink();
    final t = Curves.easeOutCubic.transform(local);
    final arc = sin(local * pi) * 20.0;
    final op = local < 0.15
        ? (local / 0.15)
        : (local > 0.72 ? (1.0 - local) / 0.28 : 1.0);
    return Transform.translate(
      offset: Offset(target.dx * t, target.dy * t - arc),
      child: Transform.scale(
        scale: 1.0 - 0.30 * t,
        child: Transform.rotate(
          angle: spin * t,
          child: Opacity(
            opacity: op.clamp(0.0, 1.0),
            child: const CardBackView(width: 28),
          ),
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
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final pop = Curves.easeOutBack.transform((t * 2.2).clamp(0.0, 1.0));
          final fade = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, -14 * t),
            child: Transform.scale(
              scale: pop,
              child: Opacity(opacity: fade, child: child),
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

/// ورقة على الطاولة: تنطلق بميل ثلاثي الأبعاد وقوس واقعي، وعند الفوز تتجمع وتنسحب للفائز.
class _PlayedCard extends StatefulWidget {
  const _PlayedCard({
    super.key,
    required this.rel,
    required this.card,
    required this.cardWidth,
    required this.isWinner,
    required this.sweepRel,
  });

  final int rel;
  final PlayingCard card;
  final double cardWidth;
  final bool isWinner;
  final int? sweepRel;

  @override
  State<_PlayedCard> createState() => _PlayedCardState();
}

class _PlayedCardState extends State<_PlayedCard> with TickerProviderStateMixin {
  static const _from = [
    Offset(0, 175),
    Offset(260, 0),
    Offset(0, -165),
    Offset(-260, 0),
  ];
  // سحب كل ورقة أولاً نحو منتصف الساحة لتتجمع فوق بعضها قبل الطيران للفائز
  static const _gatherPull = [
    Offset(0, -28),
    Offset(-32, 0),
    Offset(0, 28),
    Offset(32, 0),
  ];
  // وجهة الطيران النهائية نحو محطة الفائز (بما في ذلك كومة اللمات)
  static const _sweepTarget = [
    Offset(-90, 165),
    Offset(220, 0),
    Offset(0, -155),
    Offset(-220, 0),
  ];
  static const _restAngle = [0.0, 0.09, -0.04, -0.09];

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 340))
        ..forward();
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 580));
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
    _sweepTimer = Timer(const Duration(milliseconds: 620), () {
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
        // المرحلة 1: تجميع الورق الأربع فوق بعضها (0.0 -> 0.42)
        final gatherT = Curves.easeOutCubic.transform((swRaw / 0.42).clamp(0.0, 1.0));
        // المرحلة 2: طيران الكومة المجمّعة نحو الفائز (0.36 -> 1.0)
        final flyOutT = Curves.easeInCubic.transform(((swRaw - 0.36) / 0.64).clamp(0.0, 1.0));

        final o = _from[widget.rel];
        final pull = _gatherPull[widget.rel];

        var dx = o.dx * (1 - t) + pull.dx * gatherT;
        var dy = o.dy * (1 - t) - sin(t * pi) * 20 + pull.dy * gatherT;

        final target = widget.sweepRel;
        if (target != null && target >= 0 && target < _sweepTarget.length) {
          final dest = _sweepTarget[target];
          dx += dest.dx * flyOutT;
          dy += dest.dy * flyOutT - sin(flyOutT * pi) * 18;
        }

        final enterScale = 1.24 - 0.24 * t;
        final winnerPop = widget.isWinner ? (1.0 + 0.10 * sin(_enter.value * pi)) : 1.0;
        final sweepScale = 1.0 - 0.52 * flyOutT;
        final tiltX = (1 - t) * 0.45;
        final gatherAngle = _restAngle[widget.rel] * (1 - gatherT) +
            (widget.rel - 1.5) * 0.04 * gatherT;
        final sweepOpacity = flyOutT < 0.72
            ? 1.0
            : (1.0 - (flyOutT - 0.72) / 0.28).clamp(0.0, 1.0);

        final tiltMatrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(tiltX);

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: enterScale * winnerPop * sweepScale,
            child: Transform(
              alignment: Alignment.center,
              transform: tiltMatrix,
              child: Transform.rotate(
                angle: gatherAngle * t + (1 - t) * 0.26 + 0.22 * flyOutT,
                child: Opacity(
                  opacity: (t * sweepOpacity).clamp(0.0, 1.0).toDouble(),
                  child: child,
                ),
              ),
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

class _TeamTrickStack extends StatelessWidget {
  const _TeamTrickStack({
    required this.count,
    required this.isOurTeam,
  });

  final int count;
  final bool isOurTeam;

  @override
  Widget build(BuildContext context) {
    final visible = min(count, 4);
    final accent = isOurTeam ? const Color(0xFF34C992) : const Color(0xFFE06D44);
    return Row(
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
    );
  }
}
