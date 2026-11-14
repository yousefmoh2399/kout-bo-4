import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/game_bloc.dart';
import '../core/theme.dart';
import '../domain/card.dart';
import '../domain/rules.dart';
import 'effects.dart';
import 'strings.dart';
import 'widgets.dart';

String teamLabel(int team, int localTeam) => team == localTeam ? 'فريقكم' : 'الخصوم';

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, c) => Transform.scale(
        scale: t,
        child: Opacity(opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0).toDouble(), child: c),
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.feltDark.withAlpha(235),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withAlpha(150), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// لوحة مزايدة اللاعب (5..9 أو طاف).
class BidPanel extends StatelessWidget {
  const BidPanel({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final forced = !state.passAllowed;
    return _PanelCard(
      title: forced ? '${S.yourBid} (${S.forced})' : S.yourBid,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var b = Rules.minBid; b <= Rules.maxBid; b++)
            SizedBox(
              width: 52,
              child: GoldButton(
                label: '$b',
                onPressed: b >= state.minAllowedBid ? () => bloc.add(BidPlaced(b)) : null,
              ),
            ),
          GoldButton(
            label: S.pass,
            outlined: true,
            onPressed: state.passAllowed ? () => bloc.add(const BidPlaced(0)) : null,
          ),
        ],
      ),
    );
  }
}

class TrumpPicker extends StatelessWidget {
  const TrumpPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    return _PanelCard(
      title: S.chooseTrump,
      child: Wrap(
        spacing: 10,
        children: [
          for (final suit in Suit.values)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => bloc.add(TrumpChosen(suit)),
              child: Container(
                width: 60,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Text(
                  suit.symbol,
                  style: TextStyle(
                    fontSize: 36,
                    color: suit.isRed ? AppColors.cardRed : Colors.black87,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ملخص نهاية الجولة / اللعبة (مع مدة اللعب وعدد الجولات).
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final lt = bloc.localTeam;
    final r = state.result!;
    final over = state.phase == GamePhase.gameOver;

    final contract = '${teamLabel(r.bidderTeam, lt)} زايد بـ ${r.bid}'
        '${r.forced ? ' (${S.forced})' : ''}';
    final outcome = r.success
        ? 'نجح! +${r.points} نقطة لـ ${teamLabel(r.scoringTeam, lt)}'
        : 'فشل! +${r.points} نقطة لـ ${teamLabel(r.scoringTeam, lt)}';

    final title = over
        ? (state.winnerTeam == lt ? '🎉 فزتم باللعبة!' : 'فاز الخصوم باللعبة')
        : 'انتهت الجولة ${state.roundNumber}';

    final won = over && state.winnerTeam == lt;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (won || (!over && r.scoringTeam == lt && r.success)) const Positioned.fill(child: ConfettiOverlay()),
          _panel(context, bloc, lt, r, over, title, contract, outcome),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, GameBloc bloc, int lt, RoundResult r, bool over,
      String title, String contract, String outcome) {
    return _PanelCard(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(contract),
            const SizedBox(height: 4),
            Text(
              outcome,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: r.scoringTeam == lt ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _score('فريقكم', state.scores[lt], AppColors.gold),
                const SizedBox(width: 28),
                _score('الخصوم', state.scores[1 - lt], Colors.white),
              ],
            ),
            if (over) ...[
              const SizedBox(height: 12),
              Text(
                'مدة اللعبة ${formatDuration(state.elapsed)} • ${state.roundNumber} جولة',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            GoldButton(
              label: over ? S.newGame : S.nextRound,
              onPressed: () => bloc.add(
                over ? const GameStarted() : const NextRoundRequested(),
              ),
            ),
          ],
        ),
    );
  }

  Widget _score(String label, int value, Color color) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          AnimatedNumber(
              value: value,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
        ],
      );
}
