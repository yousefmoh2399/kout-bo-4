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

    final playerOrder = (me - state.dealer - 1 + 8) % 4;

    return SizedBox(
      height: isPortrait ? 114 : 84,
      child: LayoutBuilder(
        builder: (context, c) {
          final safeWidth = isPortrait
              ? max(240.0, c.maxWidth - 16)
              : max(220.0, c.maxWidth - 290);
          final cardW = (safeWidth / (isPortrait ? 7.0 : 9.4))
              .clamp(isPortrait ? 52.0 : 44.0, isPortrait ? 70.0 : 56.0);
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
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  left: startX + i * step,
                  top: (legal.contains(hand[i]) ? 0.0 : 12.0) +
                      pow((i - mid).abs(), 1.35) * 0.85,
                  child: _DealIn(
                    index: i,
                    playerOrder: playerOrder,
                    angle: (i - mid) * 0.026,
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
          ? (d) {
              final prevReady = _dragDy <= -24.0;
              final nextDy = (_dragDy + d.delta.dy).clamp(-56.0, 10.0);
              final nextReady = nextDy <= -24.0;
              if (!prevReady && nextReady) {
                SoundService.instance.tap();
              }
              setState(() => _dragDy = nextDy);
            }
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
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                PlayingCardView(
                  card: widget.card,
                  width: widget.width,
                  dimmed: illegalOnTurn,
                  highlighted: playable,
                ),
                if (_dragDy < -12)
                  Positioned(
                    top: -22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _dragDy <= -24
                            ? AppColors.gold
                            : Colors.black.withAlpha(190),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.goldLight,
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        _dragDy <= -24 ? 'افلت للعب ↑' : 'اسحب للأعلى ↑',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _dragDy <= -24
                              ? const Color(0xFF1A0F00)
                              : AppColors.goldLight,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// انسياب احترافي لوصول أوراق اللاعب بالتزامن مع دوره في التوزيع المتسلسل (لاعب تلو الآخر).
class _DealIn extends StatefulWidget {
  const _DealIn({
    required this.index,
    required this.playerOrder,
    required this.angle,
    required this.dxFromCenter,
    required this.child,
  });

  final int index;
  final int playerOrder;
  final double angle;
  final double dxFromCenter;
  final Widget child;

  @override
  State<_DealIn> createState() => _DealInState();
}

class _DealInState extends State<_DealIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // يبدأ توزيع أوراق هذا اللاعب بالتزامن مع موجته، وبمدة طيران كافية (16% = ~16 إطاراً) للسلاسة التامة
    final dealStart = widget.playerOrder * 0.21 + widget.index * 0.015;
    const dealSpan = 0.16;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, c) {
        final v = _c.value;
        if (v < dealStart) {
          return const SizedBox.shrink();
        }
        if (v >= dealStart + dealSpan) {
          return Transform.rotate(angle: widget.angle, child: c);
        }

        final dealLocal = ((v - dealStart) / dealSpan).clamp(0.0, 1.0);
        final flyT = Curves.easeOutQuart.transform(dealLocal);
        final arcLift = sin(flyT * pi) * 18.0;
        final dx = widget.dxFromCenter * (1.0 - flyT);
        final dy = -155.0 * (1.0 - flyT) - arcLift;
        final scale = 0.58 + 0.42 * flyT;
        final rotZ = widget.angle * flyT;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotZ,
              child: c,
            ),
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}
