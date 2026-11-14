import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/game_bloc.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/emote.dart';
import '../data/stats_repository.dart';
import 'game/game_hud.dart';
import 'game/hand_view.dart';
import 'game/player_stations.dart';
import 'game/table_surface.dart';
import 'game/trick_arena.dart';
import 'panels.dart';
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
    this.onTakeOverHost,
  });

  final GameBloc bloc;
  final VoidCallback? onClose;
  final String? roomCode;
  final Stream<Emote>? emotes;
  final ValueChanged<String>? onEmote;
  final ValueListenable<bool>? hostLost;
  final VoidCallback? onTakeOverHost;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final StreamSubscription<GameState> _sub;
  StreamSubscription<Emote>? _emoteSub;
  late GameState _prev;
  bool _saved = false;

  final ValueNotifier<Map<int, String>> _bubbles =
      ValueNotifier<Map<int, String>>({});
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
    } else if (p.trick.isComplete &&
        !s.trick.isComplete &&
        s.phase == GamePhase.playing) {
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
                label: Text(
                  phrase,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
              const Positioned.fill(
                child: DiwaniyaTableSurface(),
              ),
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
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 54,
                                color: AppColors.gold,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'انقطع الاتصال بصاحب الغرفة',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'ننتظر عودته... أو يمكنك الخروج.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (widget.onTakeOverHost != null)
                                    GoldButton(
                                      label: 'متابعة اللعب كمضيف',
                                      onPressed: widget.onTakeOverHost!,
                                    ),
                                  GoldButton(
                                    label: 'خروج',
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
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

class _GameBody extends StatelessWidget {
  const _GameBody({
    required this.state,
    required this.me,
    required this.bubbles,
    required this.onEmoteTap,
  });

  final GameState state;
  final int me;
  final ValueNotifier<Map<int, String>> bubbles;
  final VoidCallback? onEmoteTap;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final rightSeat = (me + 1) % 4;
    final partnerSeat = (me + 2) % 4;
    final leftSeat = (me + 3) % 4;
    final isAuto = s.autoSeats.contains(me);

    final humanBids =
        s.phase == GamePhase.bidding && s.currentPlayer == me && !isAuto;
    final humanTrump =
        s.phase == GamePhase.chooseTrump && s.bidder == me && !isAuto;
    final finished =
        s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = constraints.maxHeight > constraints.maxWidth * 1.05;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. ساحة رمي الأوراق الوسطية
            Positioned(
              top: isPortrait ? 120 : 62,
              bottom: isPortrait ? 186 : 86,
              left: isPortrait ? 48 : 118,
              right: isPortrait ? 48 : 118,
              child: TrickArena(state: s, me: me),
            ),

            // 2. أزرار التحكم العليا (يسار)
            Positioned(
              top: 8,
              left: 10,
              child: TopControlsPill(state: s, me: me),
            ),

            // 3. لوحة النقاط واللزمة (يمين)
            Positioned(
              top: 8,
              right: 10,
              child: ScoreAndContractHud(state: s, me: me),
            ),

            // 4. محطة الشريك
            Positioned(
              top: isPortrait ? 56 : 8,
              left: 0,
              right: 0,
              child: Center(
                child: PartnerStation(state: s, seat: partnerSeat),
              ),
            ),

            // 5. مؤشر المرحلة والدور المباشر (أو شريط اللعب التلقائي عند تفعيله)
            if (!finished && s.phase != GamePhase.idle)
              Positioned(
                top: isPortrait ? 98 : 42,
                left: 0,
                right: 0,
                child: Center(
                  child: isAuto
                      ? const AutoPlayBanner()
                      : PhaseStatusTicker(state: s, me: me),
                ),
              ),

            // 6. محطة الخصم الأيمن
            Positioned(
              right: isPortrait ? 8 : 12,
              top: isPortrait ? 108 : 56,
              bottom: isPortrait ? 168 : 58,
              child: Center(
                child: SideStation(state: s, seat: rightSeat, isRight: true),
              ),
            ),

            // 7. محطة الخصم الأيسر
            Positioned(
              left: isPortrait ? 8 : 12,
              top: isPortrait ? 108 : 56,
              bottom: isPortrait ? 168 : 58,
              child: Center(
                child: SideStation(state: s, seat: leftSeat, isRight: false),
              ),
            ),

            // 8. محطة اللاعب (أنت)
            Positioned(
              left: 10,
              bottom: isPortrait ? 128 : 12,
              child: PlayerStation(state: s, seat: me),
            ),

            // 9. زر الدردشة
            if (onEmoteTap != null)
              Positioned(
                right: 10,
                bottom: isPortrait ? 128 : 12,
                child: EmoteButton(onTap: onEmoteTap!),
              ),

            // 10. يد اللاعب في المنتصف أسفل الشاشة
            Positioned(
              bottom: isPortrait ? 6 : 2,
              left: 0,
              right: 0,
              child: HandView(state: s, me: me, isPortrait: isPortrait),
            ),

            // 11. فقاعات الدردشة العائمة
            ValueListenableBuilder<Map<int, String>>(
              valueListenable: bubbles,
              builder: (context, map, _) => Stack(
                children: [
                  for (final e in map.entries) _buildBubble(e.key, e.value),
                ],
              ),
            ),

            // 12. شاشات الحوار التفاعلية
            if (s.phase == GamePhase.idle)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 12),
                    Text(
                      'بانتظار بدء اللعبة...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            if (humanBids)
              Align(
                alignment: Alignment(0, isPortrait ? 0.0 : -0.18),
                child: BidPanel(state: s),
              ),
            if (humanTrump)
              Align(
                alignment: Alignment(0, isPortrait ? 0.0 : -0.18),
                child: const TrumpPicker(),
              ),
            if (finished) ResultOverlay(state: s),
          ],
        );
      },
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
      child: ChatBubble(key: ValueKey('$seat-$text'), text: text),
    );
  }
}
