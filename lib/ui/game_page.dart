import 'dart:async';
import 'dart:math';

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
  final VoidCallback? onClose;
  final String? roomCode;
  final Stream<Emote>? emotes;
  final ValueChanged<String>? onEmote;
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
      _saved = false;
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
            playerName: s.names[me],
          );
    }
  }

  Future<bool> _confirmExit() async {
    final ok = await showLuxuryDialog<bool>(
      context: context,
      title: 'الخروج من اللعبة؟',
      icon: Icons.exit_to_app_rounded,
      content: Text(
        widget.roomCode == null
            ? 'سيتم إنهاء اللعبة الحالية والعودة للقائمة.'
            : 'سيلعب البوت مكانك لتكمل اللعبة بدونك.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
      ),
      actions: [
        GoldButton(
          label: 'كمّل لعب',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(context, false),
        ),
        GoldButton(
          label: 'اخرج',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
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
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: BlocProvider<GameBloc>.value(
        value: widget.bloc,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. سطح طاولة الديوانية الفاخرة يغطي كامل الشاشة بدون حواف سوداء
              const Positioned.fill(
                child: DiwaniyaTableSurface(),
              ),
              // 2. ساحة اللعب التفاعلية
              SafeArea(
                child: Stack(
                  children: [
                    BlocBuilder<GameBloc, GameState>(
                      builder: (context, s) => _GameBody(
                        state: s,
                        me: widget.bloc.localSeat,
                        bubbles: _bubbles,
                        onEmoteTap: widget.onEmote == null ? null : _showPhrases,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// طاولة الديوانية البيضاوية الفاخرة: إطار ماهوجني محفور، بطانة جلدية، إضاءة كازينو، وخطوط ذهبية.
class DiwaniyaTableSurface extends StatelessWidget {
  const DiwaniyaTableSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B170C), Color(0xFF170B05), Color(0xFF2B170C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // حافة الجلد والخشب الخارجية
          Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(56),
              border: Border.all(color: AppColors.woodBorder.withAlpha(220), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(180),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
              gradient: const RadialGradient(
                center: Alignment(0, -0.05),
                radius: 1.05,
                colors: [
                  Color(0xFF1E9B63),
                  Color(0xFF137348),
                  Color(0xFF0B4E30),
                  Color(0xFF052A1A),
                ],
                stops: [0.0, 0.42, 0.78, 1.0],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // خياطة ذهبية داخلية أنيقة
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(75),
                      width: 1.2,
                    ),
                  ),
                ),
                // خط بيضاوي خفيف في قلب الطاولة
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.56,
                    heightFactor: 0.54,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(140),
                        border: Border.all(
                          color: AppColors.gold.withAlpha(24),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBody extends StatelessWidget {
  const _GameBody({
    required this.state,
    required this.me,
    required this.bubbles,
    this.onEmoteTap,
  });

  final GameState state;
  final int me;
  final ValueListenable<Map<int, String>> bubbles;
  final VoidCallback? onEmoteTap;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final humanBids = s.phase == GamePhase.bidding && s.currentPlayer == me;
    final humanTrump = s.phase == GamePhase.chooseTrump && s.bidder == me;
    final finished = (s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver) &&
        s.result != null;

    final partnerSeat = (me + 2) % 4;
    final rightSeat = (me + 1) % 4;
    final leftSeat = (me + 3) % 4;

    return Stack(
      children: [
        // 1. ساحة لعب الكروت المركزية (في المساحة الوسطى الرحبة)
        Positioned.fill(
          top: 46,
          bottom: 84,
          left: 108,
          right: 108,
          child: TrickArena(state: s, me: me),
        ),

        // 2. أدوات التحكم العلوية (أعلى اليسار)
        Positioned(
          top: 6,
          left: 12,
          child: _TopControlsPill(state: s),
        ),

        // 3. لوحة النتيجة والحكم (أعلى اليمين)
        Positioned(
          top: 6,
          right: 12,
          child: _ScoreAndContractHud(state: s, me: me),
        ),

        // 4. محطة الشريك في الأعلى في المنتصف (على الحافة العلوية مباشرة)
        Positioned(
          top: 6,
          left: 150,
          right: 150,
          child: Center(
            child: _PartnerStation(state: s, seat: partnerSeat),
          ),
        ),

        // 5. محطة الخصم الأيمن
        Positioned(
          right: 12,
          top: 56,
          bottom: 58,
          child: Center(
            child: _SideStation(state: s, seat: rightSeat, isRight: true),
          ),
        ),

        // 6. محطة الخصم الأيسر
        Positioned(
          left: 12,
          top: 56,
          bottom: 58,
          child: Center(
            child: _SideStation(state: s, seat: leftSeat, isRight: false),
          ),
        ),

        // 7. محطة اللاعب (أنت) في زاوية أسفل اليسار
        Positioned(
          left: 12,
          bottom: 10,
          child: _PlayerStation(state: s, seat: me),
        ),

        // 8. زر الدردشة في زاوية أسفل اليمين
        if (onEmoteTap != null)
          Positioned(
            right: 12,
            bottom: 10,
            child: _EmoteButton(onTap: onEmoteTap!),
          ),

        // 9. يد اللاعب في المنتصف أسفل الشاشة
        Positioned(
          bottom: 2,
          left: 0,
          right: 0,
          child: HandView(state: s, me: me),
        ),

        // 10. فقاعات الدردشة العائمة
        ValueListenableBuilder<Map<int, String>>(
          valueListenable: bubbles,
          builder: (context, map, _) => Stack(
            children: [
              for (final e in map.entries) _buildBubble(e.key, e.value),
            ],
          ),
        ),

        // 11. شاشات الحوار التفاعلية (في الجزء العلوي-الأوسط لكي لا تحجب أوراق يدك أبداً!)
        if (s.phase == GamePhase.idle)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.gold),
                SizedBox(height: 12),
                Text('بانتظار بدء اللعبة...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        if (humanBids)
          Align(
            alignment: const Alignment(0, -0.18),
            child: BidPanel(state: s),
          ),
        if (humanTrump)
          const Align(
            alignment: Alignment(0, -0.18),
            child: TrumpPicker(),
          ),
        if (finished) ResultOverlay(state: s),
      ],
    );
  }

  Widget _buildBubble(int seat, String text) {
    final rel = (seat - me + 4) % 4;
    Alignment align;
    switch (rel) {
      case 0:
        align = const Alignment(-0.68, 0.62);
        break;
      case 1:
        align = const Alignment(0.68, -0.12);
        break;
      case 2:
        align = const Alignment(0.0, -0.55);
        break;
      default:
        align = const Alignment(-0.68, -0.12);
        break;
    }
    return Align(
      alignment: align,
      child: _Bubble(key: ValueKey('$seat-$text'), text: text),
    );
  }
}

// ───────────────────────── زوايا الشريط العلوي (HUD) ─────────────────────────

class _TopControlsPill extends StatelessWidget {
  const _TopControlsPill({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xDC041B12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withAlpha(100), width: 1),
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
          const SizedBox(width: 4),
          ValueListenableBuilder<bool>(
            valueListenable: SoundService.instance.enabled,
            builder: (context, on, _) => _HudIconBtn(
              tooltip: 'الصوت',
              icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              onPressed: () => SoundService.instance.setEnabled(!on),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white24,
          ),
          ElapsedClock(state: state),
        ],
      ),
    );
  }
}

class _HudIconBtn extends StatelessWidget {
  const _HudIconBtn({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: Colors.white.withAlpha(220)),
        ),
      ),
    );
  }
}

class _ScoreAndContractHud extends StatelessWidget {
  const _ScoreAndContractHud({required this.state, required this.me});

  final GameState state;
  final int me;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final lt = Rules.teamOf(me);
    final inContract = s.bidder != null &&
        (s.phase == GamePhase.chooseTrump ||
            s.phase == GamePhase.playing ||
            s.phase == GamePhase.roundOver ||
            s.phase == GamePhase.gameOver);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // لوحة النتيجة (لنا / لهم)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE0041B12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withAlpha(160), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _teamScore('لنا', s.scores[lt], AppColors.gold, AppColors.goldLight),
              Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white24,
              ),
              _teamScore('لهم', s.scores[1 - lt], Colors.white, Colors.white70),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // شارة الحكم والمزايدة
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey('${inContract}_${s.highestBid}_${s.trump}_${s.roundNumber}'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xC8000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withAlpha(90), width: 0.9),
            ),
            child: inContract
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'مزايدة ${s.highestBid}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
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
                              fontSize: 12,
                              height: 1.05,
                              color: s.trump!.isRed ? AppColors.cardRed : AppColors.cardBlack,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        'لمات ${s.tricksWon[lt]}-${s.tricksWon[1 - lt]}',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Text(
                    'جولة ${s.roundNumber} • الهدف ${s.targetScore}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _teamScore(String label, int score, Color scoreColor, Color labelColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: labelColor, height: 1.0),
        ),
        AnimatedNumber(
          value: score,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: scoreColor, height: 1.15),
        ),
      ],
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
        const Icon(Icons.timer_outlined, size: 15, color: AppColors.goldLight),
        const SizedBox(width: 4),
        Text(
          started == null ? '00:00' : formatDuration(widget.state.elapsed),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── ساحة اللعب المركزية ─────────────────────────

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
        return const Alignment(0.0, 0.64);  // أنت (South)
      case 1:
        return const Alignment(0.64, 0.0);  // الخصم الأيمن (East)
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final arenaH = min(maxH * 0.94, 230.0).clamp(150.0, 230.0);
        final arenaW = min(maxW * 0.90, arenaH * 1.45);
        final cardW = (arenaH * 0.27).clamp(46.0, 58.0);
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
                  const Color(0xFF0A432A).withAlpha(200),
                  const Color(0xFF052416).withAlpha(220),
                ],
              ),
              border: Border.all(
                color: winner != null
                    ? AppColors.gold.withAlpha(170)
                    : AppColors.gold.withAlpha(65),
                width: winner != null ? 2.0 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: winner != null
                      ? AppColors.gold.withAlpha(45)
                      : Colors.black.withAlpha(80),
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
                    border: Border.all(color: AppColors.gold.withAlpha(28), width: 0.8),
                  ),
                ),

                // خانات نزول الورق الأربع الخفيفة
                for (var rel = 0; rel < 4; rel++)
                  Align(
                    alignment: _cardAlignment(rel),
                    child: Container(
                      width: cardW,
                      height: cardH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardW * 0.13),
                        border: Border.all(
                          color: Colors.white.withAlpha(18),
                          width: 1.0,
                        ),
                        color: Colors.black.withAlpha(22),
                      ),
                    ),
                  ),

                // الختم المركزي للحكم (أو شعار الديوانية قبل اختيار الحكم)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: s.trump != null
                      ? Container(
                          key: ValueKey('trump_${s.trump}'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xCC041B12),
                            border: Border.all(color: AppColors.gold.withAlpha(140), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 8),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.trump!.symbol,
                            style: TextStyle(
                              fontSize: 22,
                              height: 1,
                              color: s.trump!.isRed ? const Color(0xFFFF6B6B) : AppColors.goldLight,
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('no_trump'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withAlpha(40),
                            border: Border.all(color: AppColors.gold.withAlpha(45), width: 1.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '♠',
                            style: TextStyle(
                              fontSize: 22,
                              color: AppColors.gold.withAlpha(60),
                              height: 1,
                            ),
                          ),
                        ),
                ),

                // الكروت الملعوبة على الطاولة
                for (final p in s.trick.plays)
                  Align(
                    alignment: _cardAlignment(_rel(p.player)),
                    child: _PlayedCard(
                      key: ValueKey('${p.card}-${p.player}'),
                      rel: _rel(p.player),
                      card: p.card,
                      cardWidth: cardW,
                      isWinner: winner == p.player,
                      sweepRel: winner == null ? null : _rel(winner),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

/// ورقة على الطاولة: تنطلق بقوس وزاوية واقعية من مقعد اللاعب، وعند الفوز تتجمع وتنسحب للفائز.
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
  static const _restAngle = [0.0, 0.10, -0.04, -0.10];

  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 340))..forward();
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
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
    _sweepTimer = Timer(const Duration(milliseconds: 680), () {
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
        final sw = Curves.easeInCubic.transform(_sweep.value);
        final o = _from[widget.rel];

        // قوس رمية الورقة
        var dx = o.dx * (1 - t);
        var dy = o.dy * (1 - t) - sin(t * pi) * 18;

        // عند سحب اللمة للفائز
        final target = widget.sweepRel;
        if (target != null && target >= 0 && target < _from.length) {
          dx += _from[target].dx * sw;
          dy += _from[target].dy * sw;
        }

        // تأثير التقريب والرمي على الطاولة
        final enterScale = 1.22 - 0.22 * t;
        final winnerPop = widget.isWinner ? (1.0 + 0.08 * sin(_enter.value * pi)) : 1.0;
        final sweepScale = 1.0 - 0.35 * sw;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: enterScale * winnerPop * sweepScale,
            child: Transform.rotate(
              angle: _restAngle[widget.rel] * t + (1 - t) * 0.28,
              child: Opacity(
                opacity: (t * (1 - sw)).clamp(0.0, 1.0).toDouble(),
                child: child,
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

// ───────────────────────── محطات اللاعبين الأربعة ─────────────────────────

class _PartnerStation extends StatelessWidget {
  const _PartnerStation({required this.state, required this.seat});

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

    String? tag;
    if (s.phase == GamePhase.bidding) {
      final b = s.bids[seat];
      if (b != null) tag = b == 0 ? S.pass : '$b';
    } else if (s.bidder == seat && s.phase != GamePhase.idle) {
      tag = S.bidder;
    }

    final avatar = _AvatarCircle(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTurn
              ? const [Color(0xEE114730), Color(0xEE062317)]
              : const [Color(0xDE072217), Color(0xDE03140D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(75),
          width: isTurn ? 1.6 : 0.9,
        ),
        boxShadow: [
          if (isTurn) BoxShadow(color: AppColors.gold.withAlpha(135), blurRadius: 12),
          const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
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
                  Text(
                    name,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 4),
                    const _DealerChip(),
                  ],
                ],
              ),
              if (tag != null)
                Text(
                  tag,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.goldLight),
                ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _MiniCardFan(count: count),
          ],
        ],
      ),
    );
  }
}

class _SideStation extends StatelessWidget {
  const _SideStation({
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

    String? tag;
    if (s.phase == GamePhase.bidding) {
      final b = s.bids[seat];
      if (b != null) tag = b == 0 ? S.pass : '$b';
    } else if (s.bidder == seat && s.phase != GamePhase.idle) {
      tag = S.bidder;
    }

    final avatar = _AvatarCircle(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTurn
              ? const [Color(0xEE3F220E), Color(0xEE1A0D05)]
              : const [Color(0xDE072217), Color(0xDE03140D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTurn ? AppColors.goldLight : Colors.white24,
          width: isTurn ? 1.6 : 0.9,
        ),
        boxShadow: [
          if (isTurn) BoxShadow(color: AppColors.gold.withAlpha(135), blurRadius: 12),
          const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (isDealer) ...[
                  const SizedBox(width: 3),
                  const _DealerChip(),
                ],
              ],
            ),
          ),
          if (count > 0 || tag != null) const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0) _MiniCardFan(count: count),
              if (count > 0 && tag != null) const SizedBox(width: 4),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerStation extends StatelessWidget {
  const _PlayerStation({required this.state, required this.seat});

  final GameState state;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bloc = context.read<GameBloc>();
    final isTurn = s.actor == seat;
    final isDealer = s.dealer == seat;
    final name = s.names[seat];

    String? tag;
    if (s.phase == GamePhase.bidding) {
      final b = s.bids[seat];
      if (b != null) tag = b == 0 ? S.pass : '$b';
    } else if (s.bidder == seat && s.phase != GamePhase.idle) {
      tag = S.bidder;
    }

    final avatar = _AvatarCircle(
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTurn
              ? const [Color(0xEE114730), Color(0xEE062317)]
              : const [Color(0xDE072217), Color(0xDE03140D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(80),
          width: isTurn ? 1.6 : 0.9,
        ),
        boxShadow: [
          if (isTurn) BoxShadow(color: AppColors.gold.withAlpha(145), blurRadius: 12),
          const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 68),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 4),
                    const _DealerChip(),
                  ],
                ],
              ),
              Text(
                tag ?? 'أنت',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: tag != null ? FontWeight.w900 : FontWeight.w600,
                  color: tag != null ? AppColors.goldLight : Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DealerChip extends StatelessWidget {
  const _DealerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(color: Colors.white, width: 0.8),
      ),
      child: const Text(
        'D',
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF1E1304), height: 1),
      ),
    );
  }
}

/// مروحة مصغرة لأوراق المنافسين والشريك مع عداد الأوراق المتبقية.
class _MiniCardFan extends StatelessWidget {
  const _MiniCardFan({required this.count});

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

class _EmoteButton extends StatelessWidget {
  const _EmoteButton({required this.onTap});

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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.goldLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
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
        gradient: LinearGradient(
          colors: sameTeam
              ? const [Color(0xFF34C992), Color(0xFF10543B)]
              : const [Color(0xFFD97F3E), Color(0xFF662E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isTurn ? AppColors.goldLight : AppColors.gold.withAlpha(140),
          width: isTurn ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
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

/// حلقة العدّ التنازلي حول صورة اللاعب.
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
      height: 102,
      child: LayoutBuilder(
        builder: (context, c) {
          final safeWidth = max(220.0, c.maxWidth - 230);
          final cardW = (safeWidth / 9.2).clamp(48.0, 60.0);
          final n = hand.length;
          final step = n <= 1 ? 0.0 : min(cardW + 5, (safeWidth - cardW) / (n - 1));
          final total = n == 0 ? 0.0 : cardW + step * (n - 1);
          final startX = (c.maxWidth - total) / 2;
          final mid = (n - 1) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  key: ValueKey('${state.roundNumber}|${hand[i]}'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: startX + i * step,
                  top: (legal.contains(hand[i]) ? 0.0 : 14.0) + pow((i - mid).abs(), 1.35) * 0.95,
                  child: _DealIn(
                    index: i,
                    cardWidth: cardW,
                    angle: (i - mid) * 0.028,
                    child: _InteractiveHandCard(
                      card: hand[i],
                      width: cardW,
                      canPlay: canPlay,
                      isLegal: legal.contains(hand[i]),
                      onPlay: () {
                        SoundService.instance.impact();
                        context.read<GameBloc>().add(CardPlayed(hand[i]));
                      },
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
  });

  final PlayingCard card;
  final double width;
  final bool canPlay;
  final bool isLegal;
  final VoidCallback onPlay;

  @override
  State<_InteractiveHandCard> createState() => _InteractiveHandCardState();
}

class _InteractiveHandCardState extends State<_InteractiveHandCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final playable = widget.canPlay && widget.isLegal;
    return GestureDetector(
      onTapDown: playable ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: playable ? () => setState(() => _pressed = false) : null,
      onTapUp: playable
          ? (_) {
              setState(() => _pressed = false);
              widget.onPlay();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 1.10 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: PlayingCardView(
          card: widget.card,
          width: widget.width,
          dimmed: widget.canPlay && !widget.isLegal,
          highlighted: playable,
        ),
      ),
    );
  }
}

/// توزيع احترافي: تطير الورقة مقلوبة من منتصف الطاولة ثم تنقلب ثلاثياً (3D Flip) لتكشف وجهها.
class _DealIn extends StatelessWidget {
  const _DealIn({
    required this.index,
    required this.cardWidth,
    required this.angle,
    required this.child,
  });

  final int index;
  final double cardWidth;
  final double angle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final totalMs = 740 + index * 70;
    final startFrac = ((index * 62) / totalMs).clamp(0.0, 0.78);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(startFrac, 1.0, curve: Curves.linear),
      builder: (context, t, c) {
        if (t >= 0.999) {
          return Transform.rotate(angle: angle, child: c);
        }

        // المرحلة 1: الطيران مقلوبة من منتصف الطاولة إلى مكانها في اليد
        final flyT = Curves.easeOutCubic.transform((t / 0.54).clamp(0.0, 1.0));
        // المرحلة 2: الانقلاب ثلاثي الأبعاد (180 درجة) للكشف عن الورقة
        final flipT = Curves.easeInOutCubic.transform(((t - 0.54) / 0.46).clamp(0.0, 1.0));

        final dy = -185.0 * (1.0 - flyT) - sin(flipT * pi) * 7.0;
        final scale = 0.46 + 0.54 * flyT;
        final rotZ = 0.30 * (1.0 - flyT) + angle * flyT;
        final opacity = (flyT * 2.2).clamp(0.0, 1.0);

        final showFront = flipT >= 0.5;
        final flipAngle = showFront ? (1.0 - flipT) * pi : flipT * pi;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(flipAngle);

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotZ,
              child: Opacity(
                opacity: opacity,
                child: Transform(
                  alignment: Alignment.center,
                  transform: matrix,
                  child: showFront ? c : CardBackView(width: cardWidth),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
