import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/card.dart';
import '../card_view.dart';

/// يد اللاعب مع حركة توزيع 3D وانسيابية سحب/نقر للعب الورقة وتنبيه فوري للورقة غير القانونية.
class HandView extends StatefulWidget {
  const HandView({
    super.key,
    required this.state,
    required this.me,
    this.isPortrait = false,
  });

  final GameState state;
  final int me;
  final bool isPortrait;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  String? _hint;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _showIllegalHint() {
    SoundService.instance.tap();
    _hintTimer?.cancel();
    setState(() => _hint = 'يجب اتباع نوع الورقة المطلوبة');
    _hintTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final me = widget.me;
    final isPortrait = widget.isPortrait;
    final hand = state.hands[me];
    final canPlay = state.phase == GamePhase.playing &&
        state.currentPlayer == me &&
        !state.trick.isComplete;
    final List<PlayingCard> legal =
        canPlay ? state.legalMoves(me) : const <PlayingCard>[];

    return SizedBox(
      height: isPortrait ? 116 : 108,
      child: LayoutBuilder(
        builder: (context, c) {
          final safeWidth = isPortrait
              ? max(240.0, c.maxWidth - 16)
              : max(220.0, c.maxWidth - 220);
          final cardW = (safeWidth / (isPortrait ? 7.0 : 8.6)).clamp(52.0, 72.0);
          final n = hand.length;
          final step = n <= 1
              ? 0.0
              : min(cardW + 5, (safeWidth - cardW) / (n - 1));
          final total = n == 0 ? 0.0 : cardW + step * (n - 1);
          final startX = (c.maxWidth - total) / 2;
          final mid = (n - 1) / 2;
          final centerX = c.maxWidth / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  key: ValueKey('${state.roundNumber}|${hand[i]}'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: startX + i * step,
                  top: (legal.contains(hand[i]) ? 0.0 : 14.0) +
                      pow((i - mid).abs(), 1.35) * 0.95,
                  child: _DealIn(
                    index: i,
                    cardWidth: cardW,
                    angle: (i - mid) * 0.028,
                    dxFromCenter: centerX - (startX + i * step + cardW / 2),
                    child: _InteractiveHandCard(
                      card: hand[i],
                      width: cardW,
                      canPlay: canPlay,
                      isLegal: legal.contains(hand[i]),
                      onIllegalTap: _showIllegalHint,
                      onPlay: () {
                        SoundService.instance.impact();
                        context.read<GameBloc>().add(CardPlayed(hand[i]));
                      },
                    ),
                  ),
                ),
              if (_hint != null)
                Positioned(
                  top: -34,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEE3A0D0D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withAlpha(200),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                        child: Text(
                          _hint!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InteractiveHandCard extends StatefulWidget {
  const _InteractiveHandCard({
    required this.card,
    required this.width,
    required this.canPlay,
    required this.isLegal,
    required this.onPlay,
    required this.onIllegalTap,
  });

  final PlayingCard card;
  final double width;
  final bool canPlay;
  final bool isLegal;
  final VoidCallback onPlay;
  final VoidCallback onIllegalTap;

  @override
  State<_InteractiveHandCard> createState() => _InteractiveHandCardState();
}

class _InteractiveHandCardState extends State<_InteractiveHandCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  double _dragDy = 0.0;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shake.forward(from: 0);
    widget.onIllegalTap();
  }

  @override
  Widget build(BuildContext context) {
    final playable = widget.canPlay && widget.isLegal;
    final illegalOnTurn = widget.canPlay && !widget.isLegal;
    return GestureDetector(
      onTap: illegalOnTurn ? _triggerShake : null,
      onTapDown: playable ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: playable ? () => setState(() => _pressed = false) : null,
      onTapUp: playable
          ? (_) {
              setState(() => _pressed = false);
              widget.onPlay();
            }
          : null,
      onVerticalDragStart:
          playable ? (_) => setState(() => _pressed = true) : null,
      onVerticalDragUpdate: playable
          ? (d) => setState(() {
                _dragDy = (_dragDy + d.delta.dy).clamp(-56.0, 10.0);
              })
          : null,
      onVerticalDragEnd: playable
          ? (_) {
              final shouldPlay = _dragDy <= -24.0;
              setState(() {
                _pressed = false;
                _dragDy = 0.0;
              });
              if (shouldPlay) widget.onPlay();
            }
          : null,
      onVerticalDragCancel: playable
          ? () => setState(() {
                _pressed = false;
                _dragDy = 0.0;
              })
          : null,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final dx = sin(_shake.value * pi * 4) * (1.0 - _shake.value) * 6.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: _dragDy == 0.0 ? 150 : 0),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _dragDy, 0),
          child: AnimatedScale(
            scale: _pressed || _dragDy < -8 ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: PlayingCardView(
              card: widget.card,
              width: widget.width,
              dimmed: illegalOnTurn,
              highlighted: playable,
            ),
          ),
        ),
      ),
    );
  }
}

/// توزيع احترافي على مرحلتين:
/// 1) وصول الأوراق مقلوبة واحدة تلو الأخرى بالترتيب من كومة الوسط إلى اليد.
/// 2) بعد اكتمال التوزيع، تنقلب الأوراق في موجة متتابعة ثلاثية الأبعاد (3D Flip) لتكشف وجهها.
class _DealIn extends StatefulWidget {
  const _DealIn({
    required this.index,
    required this.cardWidth,
    required this.angle,
    required this.dxFromCenter,
    required this.child,
  });

  final int index;
  final double cardWidth;
  final double angle;
  final double dxFromCenter;
  final Widget child;

  @override
  State<_DealIn> createState() => _DealInState();
}

class _DealInState extends State<_DealIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1950),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // المرحلة 1 (0.00 -> 0.68): نزول كل ورقة مقلوبة بالترتيب واحدة بعد واحدة
    final dealStart = widget.index * 0.060; // 0.00 .. 0.48
    const dealSpan = 0.17; // ~330ms طيران لكل ورقة

    // المرحلة 2 (0.70 -> 1.00): بعد اكتمال توزيع الـ 9 ورقات، تنقلب في موجة متتابعة
    final flipStart = 0.70 + widget.index * 0.024; // 0.70 .. 0.892
    const flipSpan = 0.105; // ~205ms انقلاب لكل ورقة

    return AnimatedBuilder(
      animation: _c,
      builder: (context, c) {
        final v = _c.value;
        if (v < dealStart) {
          return const SizedBox.shrink();
        }
        if (v >= 0.999) {
          return Transform.rotate(angle: widget.angle, child: c);
        }

        final dealLocal = ((v - dealStart) / dealSpan).clamp(0.0, 1.0);
        final flyT = Curves.easeOutCubic.transform(dealLocal);

        final flipLocal = ((v - flipStart) / flipSpan).clamp(0.0, 1.0);
        final flipT = Curves.easeInOutCubic.transform(flipLocal);

        final arcLift = sin(flyT * pi) * 28.0;
        final flipLift = sin(flipT * pi) * 14.0;
        final dx = widget.dxFromCenter * (1.0 - flyT);
        final dy = -195.0 * (1.0 - flyT) - arcLift - flipLift;
        final scale = (0.42 + 0.58 * flyT) + sin(flipT * pi) * 0.08;
        final rotZ = (widget.dxFromCenter.sign * 0.34) * (1.0 - flyT) +
            widget.angle * flyT;
        final opacity = (flyT * 4.5).clamp(0.0, 1.0);

        final showFront = flipT >= 0.5;
        final flipAngle = showFront ? (1.0 - flipT) * pi : flipT * pi;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0022)
          ..rotateY(flipAngle);

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotZ,
              child: Opacity(
                opacity: opacity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: matrix,
                  child: showFront ? c : CardBackView(width: widget.cardWidth),
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
