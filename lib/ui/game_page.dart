import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/game_bloc.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/emote.dart';
import '../data/stats_repository.dart';
import '../domain/card.dart';
import '../domain/rules.dart';
import 'card_view.dart';
import 'effects.dart';
import 'panels.dart';
import 'strings.dart';
import 'widgets.dart';

final ValueNotifier<bool> _neverLost = ValueNotifier<bool>(false);

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.bloc,
    this.onClose,
    this.roomCode,
    this.emotes,
    this.onEmote,
    this.hostLost,
  });

  final GameBloc bloc;

  /// يُستدعى عند الخروج (مثلاً لمغادرة الغرفة وإغلاق القناة).
  final VoidCallback? onClose;
  final String? roomCode;

  /// الدردشة السريعة (أونلاين فقط).
  final Stream<Emote>? emotes;
  final ValueChanged<String>? onEmote;

  /// true = انقطع المضيف (أونلاين فقط).
  final ValueListenable<bool>? hostLost;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final StreamSubscription<GameState> _sub;
  StreamSubscription<Emote>? _emoteSub;
  late GameState _prev;
  bool _saved = false;

  final ValueNotifier<Map<int, String>> _bubbles = ValueNotifier<Map<int, String>>({});
  final Map<int, Timer> _bubbleTimers = {};

  @override
  void initState() {
    super.initState();
    _prev = widget.bloc.state;
    _sub = widget.bloc.stream.listen(_onState);
    _emoteSub = widget.emotes?.listen(_onEmote);
  }

  @override
  void dispose() {
    _sub.cancel();
    _emoteSub?.cancel();
    for (final t in _bubbleTimers.values) {
      t.cancel();
    }
    widget.bloc.close();
    widget.onClose?.call();
    super.dispose();
  }

  void _onEmote(Emote e) {
    SoundService.instance.play(Sfx.click);
    _bubbles.value = {..._bubbles.value, e.seat: e.text};
    _bubbleTimers[e.seat]?.cancel();
    _bubbleTimers[e.seat] = Timer(const Duration(milliseconds: 3000), () {
      final m = Map<int, String>.of(_bubbles.value)..remove(e.seat);
      _bubbles.value = m;
    });
  }

  int _bidCount(GameState s) => s.bids.where((b) => b != null).length;

  void _onState(GameState s) {
    final p = _prev;
    _prev = s;
    final sfx = SoundService.instance;
    final me = widget.bloc.localSeat;
    final lt = widget.bloc.localTeam;

    if (s.roundNumber != p.roundNumber ||
        (p.phase == GamePhase.idle && s.phase == GamePhase.bidding)) {
      sfx.play(Sfx.deal);
    } else if (s.trick.plays.length > p.trick.plays.length) {
      sfx.play(Sfx.card);
    } else if (_bidCount(s) > _bidCount(p) && s.phase == GamePhase.bidding) {
      sfx.play(Sfx.bid);
    } else if (p.trick.isComplete && !s.trick.isComplete && s.phase == GamePhase.playing) {
      sfx.play(Sfx.trick);
    }

    if (s.actor == me && p.actor != me) {
      sfx.play(Sfx.turn);
      sfx.tap();
    }

    final finishedNow = s.phase != p.phase &&
        (s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver) &&
        s.result != null;
    if (finishedNow) {
      sfx.play(s.result!.scoringTeam == lt ? Sfx.win : Sfx.lose);
    }

    if (p.phase == GamePhase.gameOver && s.phase != GamePhase.gameOver) {
      _saved = false; // لعبة جديدة
    }
    if (s.phase == GamePhase.gameOver && !_saved && mounted) {
      _saved = true;
      context.read<StatsRepository>().saveResult(
            roomCode: widget.roomCode,
            won: s.winnerTeam == lt,
            scoreUs: s.scores[lt],
            scoreThem: s.scores[1 - lt],
            seconds: s.elapsed.inSeconds,
            rounds: s.roundNumber,
          );
    }
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('الخروج من اللعبة؟'),
        content: Text(widget.roomCode == null
            ? 'سيتم إنهاء اللعبة الحالية.'
            : 'سيلعب البوت مكانك لتكمل اللعبة بدونك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('كمّل لعب')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اخرج')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _showPhrases() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.feltDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final phrase in kQuickPhrases)
              ActionChip(
                label: Text(phrase, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  widget.onEmote?.call(phrase);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExit();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: BlocProvider<GameBloc>.value(
        value: widget.bloc,
        child: Scaffold(
          body: FeltBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  BlocBuilder<GameBloc, GameState>(
                    builder: (context, s) => _GameBody(
                      state: s,
                      me: widget.bloc.localSeat,
                      bubbles: _bubbles,
                    ),
                  ),
                  if (widget.onEmote != null)
                    Positioned(
                      left: 12,
                      bottom: 150,
                      child: FloatingActionButton.small(
                        heroTag: 'chat',
                        backgroundColor: Colors.black54,
                        onPressed: _showPhrases,
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.hostLost ?? _neverLost,
                    builder: (context, lost, _) {
                      if (!lost) return const SizedBox.shrink();
                      return Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 54, color: AppColors.gold),
                            const SizedBox(height: 12),
                            const Text(
                              'انقطع الاتصال بصاحب الغرفة',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ننتظر عودته... أو يمكنك الخروج.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 18),
                            GoldButton(
                              label: 'خروج',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameBody extends StatelessWidget {
  const _GameBody({required this.state, required this.me, required this.bubbles});

  final GameState state;
  final int me;
  final ValueListenable<Map<int, String>> bubbles;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final humanBids = s.phase == GamePhase.bidding && s.currentPlayer == me;
    final humanTrump = s.phase == GamePhase.chooseTrump && s.bidder == me;
    final finished = (s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver) &&
        s.result != null;

    return Stack(
      children: [
        Column(
          children: [
            _TopBar(state: s, me: me),
            Expanded(child: TableView(state: s, me: me, bubbles: bubbles)),
            HandView(state: s, me: me),
          ],
        ),
        if (s.phase == GamePhase.idle)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('بانتظار بدء اللعبة...'),
              ],
            ),
          ),
        if (humanBids) Align(alignment: const Alignment(0, 0.15), child: BidPanel(state: s)),
        if (humanTrump) const Align(alignment: Alignment(0, 0.15), child: TrumpPicker()),
        if (finished) ResultOverlay(state: s),
      ],
    );
  }
}

// ───────────────────────── الشريط العلوي ─────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.me});

  final GameState state;
  final int me;

  @override
  Widget build(BuildContext context) {
    final lt = Rules.teamOf(me);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'خروج',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              ElapsedClock(state: state),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.enabled,
                builder: (context, on, _) => IconButton(
                  tooltip: 'الصوت',
                  icon: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                  onPressed: () => SoundService.instance.setEnabled(!on),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _ScorePill(label: 'فريقكم', value: state.scores[lt], color: AppColors.gold),
              Expanded(child: _ContractChip(state: state, lt: lt)),
              _ScorePill(label: 'الخصوم', value: state.scores[1 - lt], color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          AnimatedNumber(
            value: value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

class _ContractChip extends StatelessWidget {
  const _ContractChip({required this.state, required this.lt});

  final GameState state;
  final int lt;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final inContract = s.bidder != null &&
        (s.phase == GamePhase.chooseTrump ||
            s.phase == GamePhase.playing ||
            s.phase == GamePhase.roundOver ||
            s.phase == GamePhase.gameOver);

    final spans = <InlineSpan>[];
    String line2;
    if (inContract) {
      spans.add(TextSpan(text: 'مزايدة ${s.highestBid}  '));
      if (s.trump != null) {
        spans.add(TextSpan(
          text: s.trump!.symbol,
          style: TextStyle(
            fontSize: 22,
            color: s.trump!.isRed ? const Color(0xFFFF6B5E) : Colors.white,
          ),
        ));
      }
      line2 = 'اللمات ${s.tricksWon[lt]} - ${s.tricksWon[1 - lt]}';
    } else {
      spans.add(TextSpan(text: 'الجولة ${s.roundNumber}'));
      line2 = 'الهدف ${s.targetScore} نقطة';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('${inContract}_${s.highestBid}_${s.trump}_${s.roundNumber}'),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(60),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text.rich(
              TextSpan(children: spans),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(line2, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 18, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          started == null ? '00:00' : formatDuration(widget.state.elapsed),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── الطاولة ─────────────────────────

class TableView extends StatelessWidget {
  const TableView({super.key, required this.state, required this.me, required this.bubbles});

  final GameState state;
  final int me;
  final ValueListenable<Map<int, String>> bubbles;

  int _rel(int seat) => (seat - me + 4) % 4;

  static Alignment _seatAlignment(int rel) {
    switch (rel) {
      case 0:
        return Alignment.bottomCenter;
      case 1:
        return Alignment.centerRight;
      case 2:
        return Alignment.topCenter;
      default:
        return Alignment.centerLeft;
    }
  }

  static Alignment _cardAlignment(int rel) {
    switch (rel) {
      case 0:
        return const Alignment(0, 0.42);
      case 1:
        return const Alignment(0.42, 0);
      case 2:
        return const Alignment(0, -0.42);
      default:
        return const Alignment(-0.42, 0);
    }
  }

  static Alignment _bubbleAlignment(int rel) {
    switch (rel) {
      case 0:
        return const Alignment(0, 0.78);
      case 1:
        return const Alignment(0.72, -0.35);
      case 2:
        return const Alignment(0, -0.78);
      default:
        return const Alignment(-0.72, -0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final winner = s.trick.isComplete && s.trump != null
        ? Rules.trickWinner(s.trick, s.trump!)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: AppColors.woodLight, width: 8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
          gradient: const RadialGradient(
            colors: [Color(0xFF1E8F5C), AppColors.felt],
            radius: 0.9,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            children: [
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    s.trump?.symbol ?? '♠',
                    key: ValueKey(s.trump),
                    style: TextStyle(fontSize: 150, color: Colors.white.withAlpha(16)),
                  ),
                ),
              ),
              for (var rel = 0; rel < 4; rel++)
                Align(
                  alignment: _seatAlignment(rel),
                  child: SeatView(state: s, seat: (me + rel) % 4, me: me),
                ),
              for (final p in s.trick.plays)
                Align(
                  alignment: _cardAlignment(_rel(p.player)),
                  child: _PlayedCard(
                    key: ValueKey(p.card),
                    rel: _rel(p.player),
                    card: p.card,
                    isWinner: winner == p.player,
                    sweepRel: winner == null ? null : _rel(winner),
                  ),
                ),
              ValueListenableBuilder<Map<int, String>>(
                valueListenable: bubbles,
                builder: (context, map, _) => Stack(
                  children: [
                    for (final e in map.entries)
                      Align(
                        alignment: _bubbleAlignment(_rel(e.key)),
                        child: _Bubble(key: ValueKey('${e.key}-${e.value}'), text: e.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text});

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
        child: Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// ورقة على الطاولة: تدخل من مقعد اللاعب، وعند اكتمال اللمة تنزلق نحو الفائز.
class _PlayedCard extends StatefulWidget {
  const _PlayedCard({
    super.key,
    required this.rel,
    required this.card,
    required this.isWinner,
    required this.sweepRel,
  });

  final int rel;
  final PlayingCard card;
  final bool isWinner;
  final int? sweepRel;

  @override
  State<_PlayedCard> createState() => _PlayedCardState();
}

class _PlayedCardState extends State<_PlayedCard> with TickerProviderStateMixin {
  static const _from = [Offset(0, 170), Offset(170, 0), Offset(0, -170), Offset(-170, 0)];
  static const _angle = [0.0, 0.18, -0.08, -0.18];

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
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
    _sweepTimer = Timer(const Duration(milliseconds: 650), () {
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
        final sw = Curves.easeIn.transform(_sweep.value);
        final o = _from[widget.rel];
        var dx = o.dx * (1 - t);
        var dy = o.dy * (1 - t);
        final target = widget.sweepRel;
        if (target != null) {
          dx += _from[target].dx * sw;
          dy += _from[target].dy * sw;
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: 1 - 0.3 * sw,
            child: Transform.rotate(
              angle: _angle[widget.rel] * t,
              child: Opacity(opacity: (t * (1 - sw)).clamp(0.0, 1.0).toDouble(), child: child),
            ),
          ),
        );
      },
      child: PlayingCardView(card: widget.card, width: 52, highlighted: widget.isWinner),
    );
  }
}

class SeatView extends StatelessWidget {
  const SeatView({super.key, required this.state, required this.seat, required this.me});

  final GameState state;
  final int seat;
  final int me;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bloc = context.read<GameBloc>();
    final isTurn = s.actor == seat;
    final sameTeam = Rules.teamOf(seat) == Rules.teamOf(me);
    final name = s.names[seat];

    String? tag;
    if (s.phase == GamePhase.bidding) {
      final b = s.bids[seat];
      if (b != null) tag = b == 0 ? S.pass : '$b';
    } else if (s.bidder == seat && s.phase != GamePhase.idle) {
      tag = S.bidder;
    }

    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: sameTeam ? const Color(0xFF2E7D6B) : const Color(0xFF8D5A2B),
        border: Border.all(color: isTurn ? AppColors.gold : Colors.white38, width: isTurn ? 3 : 1.5),
        boxShadow: isTurn ? [BoxShadow(color: AppColors.gold.withAlpha(130), blurRadius: 14)] : null,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    final end = s.turnEndsAt;
    final Widget head = (isTurn && end != null && bloc.turnSeconds > 0)
        ? TurnRing(endsAt: end, total: bloc.turnSeconds, playTick: seat == me, child: avatar)
        : avatar;

    final count = s.hands[seat].length;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: tag == null
                ? const SizedBox(key: ValueKey('none'), height: 0)
                : Container(
                    key: ValueKey(tag),
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tag, style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                  ),
          ),
          if (seat != me && count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: CardBackView(width: 24, label: '$count'),
            ),
        ],
      ),
    );
  }
}

/// حلقة العدّ التنازلي حول صورة اللاعب.
class TurnRing extends StatefulWidget {
  const TurnRing({
    super.key,
    required this.endsAt,
    required this.total,
    required this.playTick,
    required this.child,
  });

  final DateTime endsAt;
  final int total;
  final bool playTick;
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
          width: 58,
          height: 58,
          child: CircularProgressIndicator(
            value: frac,
            strokeWidth: 4,
            color: frac < 0.25 ? AppColors.danger : AppColors.gold,
            backgroundColor: Colors.white24,
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ───────────────────────── يد اللاعب ─────────────────────────

class HandView extends StatelessWidget {
  const HandView({super.key, required this.state, required this.me});

  final GameState state;
  final int me;

  @override
  Widget build(BuildContext context) {
    final hand = state.hands[me];
    final canPlay = state.phase == GamePhase.playing &&
        state.currentPlayer == me &&
        !state.trick.isComplete;
    final List<PlayingCard> legal = canPlay ? state.legalMoves(me) : const <PlayingCard>[];

    return SizedBox(
      height: 132,
      child: LayoutBuilder(
        builder: (context, c) {
          const cardW = 62.0;
          final n = hand.length;
          final step = n <= 1 ? 0.0 : min(cardW + 6, (c.maxWidth - cardW - 16) / (n - 1));
          final total = n == 0 ? 0.0 : cardW + step * (n - 1);
          final startX = (c.maxWidth - total) / 2;
          final mid = (n - 1) / 2;
          return Stack(
            children: [
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  key: ValueKey('${state.roundNumber}|${hand[i]}'),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: startX + i * step,
                  top: (legal.contains(hand[i]) ? 6.0 : 26.0) + (i - mid).abs() * 2.5,
                  child: _DealIn(
                    index: i,
                    child: Transform.rotate(
                      angle: (i - mid) * 0.04,
                      child: GestureDetector(
                        onTap: legal.contains(hand[i])
                            ? () {
                                SoundService.instance.impact();
                                context.read<GameBloc>().add(CardPlayed(hand[i]));
                              }
                            : null,
                        child: PlayingCardView(
                          card: hand[i],
                          width: cardW,
                          dimmed: canPlay && !legal.contains(hand[i]),
                          highlighted: legal.contains(hand[i]),
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

/// دخول الورقة من منتصف الطاولة عند التوزيع (متدرج حسب ترتيبها).
class _DealIn extends StatelessWidget {
  const _DealIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ms = 380 + index * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Interval(index * 70 / ms, 1, curve: Curves.easeOutCubic),
      builder: (context, t, c) => Transform.translate(
        offset: Offset(0, -240 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0).toDouble(), child: c),
      ),
      child: child,
    );
  }
}
