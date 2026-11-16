import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import '../strings.dart';

BoxDecoration _stationDecoration({required bool isTurn, required bool sameTeam}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: isTurn
          ? (sameTeam
              ? const [Color(0xF6105439), Color(0xF6062A1C)]
              : const [Color(0xF6521A15), Color(0xF6280B07)])
          : const [Color(0xF008271B), Color(0xF003150E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(75),
      width: isTurn ? 1.8 : 1.0,
    ),
    boxShadow: [
      if (isTurn) ...[
        BoxShadow(
          color: AppColors.gold.withAlpha(140),
          blurRadius: 14,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: sameTeam
              ? const Color(0xFF2ECC71).withAlpha(65)
              : const Color(0xFFE74C3C).withAlpha(65),
          blurRadius: 8,
        ),
      ],
      const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
    ],
  );
}

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
    final name = s.names[seat];
    final count = s.hands[seat].length;
    final tag = _seatTag(s, seat);

    final avatar = AvatarCircle(
      name: name,
      isTurn: isTurn,
      sameTeam: true,
      size: 32,
      iconData: Icons.handshake_rounded,
    );

    final end = s.turnEndsAt;
    final Widget head = (isTurn && end != null && bloc.turnSeconds > 0)
        ? TurnRing(endsAt: end, total: bloc.turnSeconds, playTick: false, size: 38, child: avatar)
        : avatar;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: _stationDecoration(isTurn: isTurn, sameTeam: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 4),
                    const DealerChip(),
                  ],
                ],
              ),
              if (tag != null)
                _AnimatedTag(tag: tag)
              else
                const Text(
                  'الشريك',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF7DE0B7)),
                ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            MiniCardFan(count: count),
          ],
        ],
      ),
    );
  }
}

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
    final name = s.names[seat];
    final count = s.hands[seat].length;
    final tag = _seatTag(s, seat);

    final avatar = AvatarCircle(
      name: name,
      isTurn: isTurn,
      sameTeam: false,
      size: 36,
      iconData: isRight ? Icons.shield_rounded : Icons.flash_on_rounded,
    );

    final end = s.turnEndsAt;
    final Widget head = (isTurn && end != null && bloc.turnSeconds > 0)
        ? TurnRing(endsAt: end, total: bloc.turnSeconds, playTick: false, size: 42, child: avatar)
        : avatar;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: _stationDecoration(isTurn: isTurn, sameTeam: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isDealer) ...[
                  const SizedBox(width: 3),
                  const DealerChip(),
                ],
              ],
            ),
          ),
          if (count > 0 || tag != null) const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0) MiniCardFan(count: count),
              if (count > 0 && tag != null) const SizedBox(width: 4),
              if (tag != null) _AnimatedTag(tag: tag),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final name = s.names[seat];
    final tag = _seatTag(s, seat);

    final avatar = AvatarCircle(
      name: name,
      isTurn: isTurn,
      sameTeam: true,
      size: 34,
      iconData: Icons.workspace_premium_rounded,
    );

    final end = s.turnEndsAt;
    final Widget head = (isTurn && end != null && bloc.turnSeconds > 0)
        ? TurnRing(endsAt: end, total: bloc.turnSeconds, playTick: true, size: 40, child: avatar)
        : avatar;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: _stationDecoration(isTurn: isTurn, sameTeam: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 4),
                    const DealerChip(),
                  ],
                ],
              ),
              if (tag != null)
                _AnimatedTag(tag: tag)
              else
                const Text(
                  'أنت',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white60),
                ),
            ],
          ),
          if (s.tricksWon[Rules.teamOf(seat)] > 0) ...[
            const SizedBox(width: 8),
            TrickPileStack(
              count: s.tricksWon[Rules.teamOf(seat)],
              sameTeam: true,
            ),
          ],
        ],
      ),
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

class _AnimatedTag extends StatelessWidget {
  const _AnimatedTag({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(tag),
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.gold.withAlpha(55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}

class DealerChip extends StatelessWidget {
  const DealerChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
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
        border: Border.all(color: AppColors.goldLight, width: 0.9),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: const Text(
        'D',
        style: TextStyle(
          fontSize: 8.5,
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
    final visible = min(count, 3);
    final w = 13.0 + (visible - 1) * 4.5;
    return SizedBox(
      width: w + 10,
      height: 22,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * 4.5,
              child: Transform.rotate(
                angle: (i - (visible - 1) / 2) * 0.12,
                child: const CardBackView(width: 13),
              ),
            ),
          Positioned(
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withAlpha(180), width: 0.8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.95,
          colors: sameTeam
              ? const [Color(0xFF38E09B), Color(0xFF147E53), Color(0xFF073C26)]
              : const [Color(0xFFFF6B6B), Color(0xFFA82626), Color(0xFF520E0E)],
        ),
        border: Border.all(
          color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(160),
          width: isTurn ? 2.2 : 1.3,
        ),
        boxShadow: [
          if (isTurn) ...[
            BoxShadow(
              color: AppColors.gold.withAlpha(140),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: sameTeam
                  ? const Color(0xFF2ECC71).withAlpha(80)
                  : const Color(0xFFE74C3C).withAlpha(80),
              blurRadius: 8,
            ),
          ],
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: iconData != null
          ? Icon(iconData, size: size * 0.54, color: Colors.white)
          : Text(
              name.isEmpty ? '?' : name.characters.first,
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
              ),
            ),
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
    final leftMs = max(0, widget.endsAt.difference(DateTime.now()).inMilliseconds);
    final frac = (leftMs / (widget.total * 1000)).clamp(0.0, 1.0).toDouble();
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

/// كومة اللمات المجمّعة: ترص الأوراق المقلوبة فوق بعضها مع شارة العدد وحركة نبض عند كسب لمة جديدة.
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
    final layers = min(count, 6);
    return TweenAnimationBuilder<double>(
      key: ValueKey('pile_${sameTeam}_$count'),
      tween: Tween(begin: 1.24, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: SizedBox(
        width: 28,
        height: 26,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (var i = 0; i < layers; i++)
              Positioned(
                bottom: i * 1.4,
                left: 5 + (i.isEven ? -0.5 : 0.5),
                child: Transform.rotate(
                  angle: (i - (layers - 1) / 2) * 0.04,
                  child: const CardBackView(width: 14),
                ),
              ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                decoration: BoxDecoration(
                  color: sameTeam ? AppColors.gold : const Color(0xFFD9643A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black54, width: 0.7),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 8.5,
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
