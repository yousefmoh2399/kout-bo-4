import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import '../effects.dart';
import '../panels.dart';
import '../widgets.dart';

class TopControlsPill extends StatelessWidget {
  const TopControlsPill({super.key, required this.state, required this.me});

  final GameState state;
  final int me;

  Future<void> _showLastTrick(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final plays = state.lastTrick;
    if (plays.isEmpty) return;
    final winner = state.lastTrickWinner;
    await showLuxuryDialog<void>(
      context: context,
      title: 'آخر أكلة',
      icon: Icons.history_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (winner != null) ...[
            Text(
              'أخذها: ${state.names[winner]}',
              style: const TextStyle(
                color: AppColors.goldLight,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final p in plays)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCardView(
                      card: p.card,
                      width: 50,
                      highlighted: p.player == winner,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.names[p.player],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            p.player == winner ? FontWeight.w800 : FontWeight.w600,
                        color: p.player == winner
                            ? AppColors.goldLight
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      actions: [
        GoldButton(
          label: 'إغلاق',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _confirmRestart(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final ok = await showLuxuryDialog<bool>(
      context: context,
      title: 'إعادة المباراة؟',
      icon: Icons.replay_rounded,
      content: const Text(
        'سيتم تصفير النقاط الحالية وبدء مباراة جديدة من البداية.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(context, false),
        ),
        GoldButton(
          label: 'إعادة المباراة',
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true && context.mounted) {
      context.read<GameBloc>().add(const GameStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final isAuto = state.autoSeats.contains(me);
    final canRestart = !bloc.remote && state.phase != GamePhase.idle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xCC041810),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAuto ? AppColors.gold : Colors.white.withAlpha(34),
          width: isAuto ? 1.4 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HudIconBtn(
            tooltip: 'خروج',
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 2),
          ValueListenableBuilder<bool>(
            valueListenable: SoundService.instance.enabled,
            builder: (context, on, _) => _HudIconBtn(
              tooltip: 'الصوت',
              icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              onPressed: () => SoundService.instance.setEnabled(!on),
            ),
          ),
          const SizedBox(width: 2),
          _HudIconBtn(
            tooltip: isAuto ? 'إيقاف اللعب التلقائي' : 'تشغيل اللعب التلقائي',
            icon: Icons.smart_toy_rounded,
            color: isAuto ? AppColors.goldLight : Colors.white.withAlpha(200),
            onPressed: () {
              SoundService.instance.play(Sfx.click);
              bloc.add(AutoPlayToggled(enabled: !isAuto));
            },
          ),
          if (state.lastTrick.isNotEmpty) ...[
            const SizedBox(width: 2),
            _HudIconBtn(
              tooltip: 'آخر أكلة',
              icon: Icons.history_rounded,
              onPressed: () => _showLastTrick(context),
            ),
          ],
          if (canRestart) ...[
            const SizedBox(width: 2),
            _HudIconBtn(
              tooltip: 'إعادة المباراة',
              icon: Icons.replay_rounded,
              onPressed: () => _confirmRestart(context),
            ),
          ],
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: Colors.white24,
          ),
          ElapsedClock(state: state),
        ],
      ),
    );
  }
}

class _HudIconBtn extends StatelessWidget {
  const _HudIconBtn({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16.5, color: color ?? Colors.white.withAlpha(220)),
        ),
      ),
    );
  }
}

class ScoreAndContractHud extends StatelessWidget {
  const ScoreAndContractHud({super.key, required this.state, required this.me});

  final GameState state;
  final int me;

  Future<void> _showRoundHistory(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final lt = Rules.teamOf(me);
    final history = state.roundHistory;
    await showLuxuryDialog<void>(
      context: context,
      title: 'تفاصيل الجولات',
      icon: Icons.receipt_long_rounded,
      content: history.isEmpty
          ? const Text(
              'لم تنتهِ أي جولة بعد في هذه المباراة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < history.length; i++)
                      _RoundHistoryRow(
                        roundNumber: i + 1,
                        result: history[i],
                        localTeam: lt,
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        GoldButton(
          label: 'إغلاق',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final lt = Rules.teamOf(me);
    final inContract = s.bidder != null &&
        (s.phase == GamePhase.chooseTrump ||
            s.phase == GamePhase.playing ||
            s.phase == GamePhase.roundOver ||
            s.phase == GamePhase.gameOver);
    final showTricks = s.phase == GamePhase.playing ||
        s.phase == GamePhase.roundOver ||
        s.phase == GamePhase.gameOver;

    return GestureDetector(
      onTap: () => _showRoundHistory(context),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD4041810),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(34), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(115),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _teamScore(
                label: 'لنا',
                score: s.scores[lt],
                tricks: showTricks ? s.tricksWon[lt] : null,
                accent: AppColors.goldLight,
                dotColor: const Color(0xFF34C992),
              ),
              Container(
                height: 18,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white12,
              ),
              _teamScore(
                label: 'لهم',
                score: s.scores[1 - lt],
                tricks: showTricks ? s.tricksWon[1 - lt] : null,
                accent: Colors.white,
                dotColor: const Color(0xFFE06D44),
              ),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Container(
              key: ValueKey('${inContract}_${s.highestBid}_${s.trump}_${s.roundNumber}'),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: inContract
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'طلب ${s.highestBid}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: AppColors.goldLight,
                          ),
                        ),
                        if (s.trump != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.trump!.symbol,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.05,
                                color: s.trump!.isRed ? AppColors.cardRed : AppColors.cardBlack,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          'جولة ${s.roundNumber}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'جولة ${s.roundNumber} • الهدف ${s.targetScore}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _teamScore({
    required String label,
    required int score,
    required int? tricks,
    required Color accent,
    required Color dotColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: accent.withAlpha(210),
          ),
        ),
        const SizedBox(width: 5),
        AnimatedNumber(
          value: score,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (tricks != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            decoration: BoxDecoration(
              color: dotColor.withAlpha(42),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: dotColor.withAlpha(110), width: 0.7),
            ),
            child: Text(
              '$tricks',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// مؤشر حي لحالة الدور والمرحلة الحالية.
class PhaseStatusTicker extends StatelessWidget {
  const PhaseStatusTicker({super.key, required this.state, required this.me});

  final GameState state;
  final int me;

  @override
  Widget build(BuildContext context) {
    final actor = state.actor;
    if (actor == null || state.phase == GamePhase.idle || state.trick.isComplete) {
      return const SizedBox.shrink();
    }
    final isMe = actor == me && !state.autoSeats.contains(me);
    final actorName = state.names[actor];

    String text;
    if (state.phase == GamePhase.bidding) {
      text = isMe ? 'دورك للمزايدة' : 'المزايدة: $actorName';
    } else if (state.phase == GamePhase.chooseTrump) {
      text = isMe ? 'اختر لون الحكم' : '$actorName يختار الحكم';
    } else {
      text = isMe ? 'دورك الآن — العب ورقة' : 'الدور عند $actorName';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isMe ? AppColors.gold.withAlpha(235) : const Color(0xB8041810),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withAlpha(180) : Colors.white.withAlpha(34),
            width: 0.9,
          ),
          boxShadow: [
            if (isMe) BoxShadow(color: AppColors.gold.withAlpha(110), blurRadius: 10),
            const BoxShadow(color: Colors.black38, blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ...[
              const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF1E1304)),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isMe ? const Color(0xFF1E1304) : Colors.white.withAlpha(220),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AutoPlayBanner extends StatelessWidget {
  const AutoPlayBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, c) => Transform.scale(scale: t, child: c),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            SoundService.instance.play(Sfx.click);
            context.read<GameBloc>().add(const AutoPlayToggled(enabled: false));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xEE183F2D), Color(0xEE081E14)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(140),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(color: AppColors.gold.withAlpha(55), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_rounded, size: 17, color: AppColors.goldLight),
                const SizedBox(width: 7),
                const Text(
                  'البوت يلعب عنك',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.goldLight, AppColors.gold],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'إيقاف واللعب بنفسي',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1304),
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

class EmoteButton extends StatelessWidget {
  const EmoteButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xDC041B12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withAlpha(140), width: 1.0),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          SoundService.instance.play(Sfx.click);
          onTap();
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppColors.goldLight),
              SizedBox(width: 5),
              Text(
                'دردشة',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0).toDouble(), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// ساعة مدة اللعبة (تتجمد عند نهايتها).
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({super.key, required this.state});

  final GameState state;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.state.endedAt == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.state.startedAt;
    final matchEnd = widget.state.matchEndsAt;
    Duration? remaining;
    var urgent = false;
    if (matchEnd != null) {
      final diff = matchEnd.difference(widget.state.endedAt ?? DateTime.now());
      remaining = diff.isNegative ? Duration.zero : diff;
      urgent = remaining.inSeconds <= 30;
    }

    final color = urgent ? AppColors.danger : AppColors.goldLight;
    final label = remaining != null
        ? formatDuration(remaining)
        : (started == null ? '00:00' : formatDuration(widget.state.elapsed));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          remaining != null ? Icons.hourglass_bottom_rounded : Icons.timer_outlined,
          size: 14.5,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: urgent ? AppColors.danger : Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RoundHistoryRow extends StatelessWidget {
  const _RoundHistoryRow({
    required this.roundNumber,
    required this.result,
    required this.localTeam,
  });

  final int roundNumber;
  final RoundResult result;
  final int localTeam;

  @override
  Widget build(BuildContext context) {
    final bidderIsUs = result.bidderTeam == localTeam;
    final bidderLabel = bidderIsUs ? 'فريقنا' : 'الخصم';
    final bidLabel = result.forced ? 'ملزوم (${result.bid})' : 'طلب ${result.bid}';
    final statusLabel = result.success ? 'نجح' : 'انكسر';
    final usScored = result.scoringTeam == localTeam;
    final ptsColor = usScored ? const Color(0xFF4BE0A8) : const Color(0xFFFF7A6B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.gold.withAlpha(35),
            child: Text(
              '$roundNumber',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.goldLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$bidderLabel • $bidLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: result.success ? const Color(0xFF4BE0A8) : Colors.amberAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${result.points} ${usScored ? "لنا" : "لهم"}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ptsColor,
            ),
          ),
        ],
      ),
    );
  }
}
