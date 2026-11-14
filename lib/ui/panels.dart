import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/game_bloc.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../domain/card.dart';
import '../domain/rules.dart';
import 'effects.dart';
import 'strings.dart';
import 'widgets.dart';

String teamLabel(int team, int localTeam) => team == localTeam ? 'لنا' : 'لهم';

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// شريط عائم أنيق لا يحجب أوراق اللاعب في الوضع الأفقي.
class _FloatingActionBar extends StatelessWidget {
  const _FloatingActionBar({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, t, c) => Transform.scale(
        scale: t,
        child: Opacity(opacity: ((t - 0.88) / 0.12).clamp(0.0, 1.0).toDouble(), child: c),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xEB041B12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withAlpha(200), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: AppColors.gold.withAlpha(35), blurRadius: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.gold, size: 17),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.goldLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// لوحة المزايدة الأنيقة على شكل شريط أفقي من الفيشات الذهبية لا يحجب اليد.
class BidPanel extends StatelessWidget {
  const BidPanel({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final forced = !state.passAllowed;

    return _FloatingActionBar(
      title: forced ? '${S.yourBid} (${S.forced})' : S.yourBid,
      icon: Icons.gavel_rounded,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var b = Rules.minBid; b <= Rules.maxBid; b++) ...[
            _BidChip(
              value: b,
              enabled: b >= state.minAllowedBid,
              onPressed: () {
                SoundService.instance.play(Sfx.bid);
                bloc.add(BidPlaced(b));
              },
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            height: 40,
            child: GoldButton(
              label: S.pass,
              outlined: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              onPressed: state.passAllowed
                  ? () {
                      SoundService.instance.play(Sfx.click);
                      bloc.add(const BidPlaced(0));
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}


class _BidChip extends StatelessWidget {
  const _BidChip({required this.value, required this.enabled, required this.onPressed});

  final int value;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled
                  ? const LinearGradient(
                      colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled ? null : Colors.white.withAlpha(20),
              border: Border.all(
                color: enabled ? AppColors.goldLight : Colors.white24,
                width: 1.4,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                color: enabled ? const Color(0xFF1F1404) : Colors.white30,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// لوحة اختيار الحكم الملكية بشكل أفقي مضغوط وأنيق.
class TrumpPicker extends StatelessWidget {
  const TrumpPicker({super.key});

  static const _suitNames = {
    Suit.spades: 'سباتي',
    Suit.hearts: 'هاص',
    Suit.diamonds: 'ديمن',
    Suit.clubs: 'شري',
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    return _FloatingActionBar(
      title: S.chooseTrump,
      icon: Icons.shield_rounded,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < Suit.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _SuitOption(
              suit: Suit.values[i],
              label: _suitNames[Suit.values[i]] ?? '',
              onTap: () {
                SoundService.instance.play(Sfx.bid);
                bloc.add(TrumpChosen(Suit.values[i]));
              },
            ),
          ],
        ],
      ),
    );
  }
}


class _SuitOption extends StatelessWidget {
  const _SuitOption({required this.suit, required this.label, required this.onTap});

  final Suit suit;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 62,
          height: 68,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), AppColors.cardCream],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                suit.symbol,
                style: TextStyle(
                  fontSize: 28,
                  height: 1,
                  color: suit.isRed ? AppColors.cardRed : AppColors.cardBlack,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: suit.isRed ? AppColors.cardRed : AppColors.cardBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ملخص نهاية الجولة / اللعبة مع شاشة احتفالية وتأثيرات الفوز.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final lt = bloc.localTeam;
    final r = state.result;
    final over = state.phase == GamePhase.gameOver;
    final won = over && state.winnerTeam == lt;

    final contract = r == null
        ? 'انتهى الوقت المحدد للمباراة'
        : '${teamLabel(r.bidderTeam, lt)} زايد بـ ${r.bid}'
            '${r.forced ? ' (${S.forced})' : ''}';
    final outcome = r == null
        ? (won ? 'الفوز بأعلى نقاط' : 'انتهت المباراة بأعلى نقاط')
        : (r.success
            ? 'نجح! +${r.points} نقطة لـ ${teamLabel(r.scoringTeam, lt)}'
            : 'فشل! +${r.points} نقطة لـ ${teamLabel(r.scoringTeam, lt)}');

    final title = over
        ? (state.winnerTeam == lt ? 'مبروك! فزتم باللعبة' : 'فاز الخصوم باللعبة')
        : 'انتهت الجولة ${state.roundNumber}';

    final outcomePositive = r == null ? won : r.scoringTeam == lt;

    return Container(
      color: Colors.black.withAlpha(170),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (won || (!over && r != null && r.scoringTeam == lt && r.success))
            const Positioned.fill(child: ConfettiOverlay()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, t, c) => Transform.scale(
                  scale: t,
                  child: Opacity(opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0).toDouble(), child: c),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xF5072015),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.gold.withAlpha(200), width: 1.8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(170), blurRadius: 24, offset: const Offset(0, 8)),
                      BoxShadow(color: AppColors.gold.withAlpha(40), blurRadius: 18),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            won
                                ? Icons.emoji_events_rounded
                                : (over ? Icons.sports_score_rounded : Icons.flag_rounded),
                            color: AppColors.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contract,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (outcomePositive ? AppColors.success : AppColors.danger).withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (outcomePositive ? AppColors.success : AppColors.danger).withAlpha(160),
                          ),
                        ),
                        child: Text(
                          outcome,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: outcomePositive ? const Color(0xFF68D391) : const Color(0xFFFC8181),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ScorePlate(
                            label: 'لنا',
                            value: state.scores[lt],
                            color: AppColors.gold,
                            isWinner: won,
                          ),
                          const Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white38)),
                          _ScorePlate(
                            label: 'لهم',
                            value: state.scores[1 - lt],
                            color: Colors.white,
                            isWinner: over && !won,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TargetProgressBar(
                        us: state.scores[lt],
                        them: state.scores[1 - lt],
                        target: state.targetScore,
                      ),
                      if (over) ...[
                        const SizedBox(height: 10),
                        Text(
                          'مدة اللعبة ${formatDuration(state.elapsed)} • ${state.roundNumber} جولات',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (over)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            GoldButton(
                              label: 'الرئيسية',
                              icon: Icons.home_rounded,
                              outlined: true,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            GoldButton(
                              label: 'إعادة المباراة',
                              icon: Icons.replay_rounded,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                              onPressed: () => bloc.add(const GameStarted()),
                            ),
                          ],
                        )
                      else
                        GoldButton(
                          label: S.nextRound,
                          icon: Icons.arrow_forward_rounded,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          onPressed: () => bloc.add(const NextRoundRequested()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ScorePlate extends StatelessWidget {
  const _ScorePlate({
    required this.label,
    required this.value,
    required this.color,
    required this.isWinner,
  });

  final String label;
  final int value;
  final Color color;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWinner ? AppColors.gold : Colors.white24,
          width: isWinner ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
          AnimatedNumber(
            value: value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetProgressBar extends StatelessWidget {
  const _TargetProgressBar({
    required this.us,
    required this.them,
    required this.target,
  });

  final int us;
  final int them;
  final int target;

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 51 : target;
    final usFrac = (us / safeTarget).clamp(0.0, 1.0);
    final themFrac = (them / safeTarget).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الهدف: $safeTarget نقطة',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            Text(
              'لنا $us / لهم $them',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 7,
            child: Stack(
              children: [
                Container(color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: themFrac,
                  child: Container(color: Colors.white38),
                ),
                FractionallySizedBox(
                  widthFactor: usFrac,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.gold, AppColors.goldLight],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

