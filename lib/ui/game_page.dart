import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/game_bloc.dart';
import '../core/connectivity_service.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/emote.dart';
import '../data/stats_repository.dart';
import '../domain/rules.dart';
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
    this.roomStake = 0,
    this.isHost = false,
    this.emotes,
    this.onEmote,
    this.onBackground,
    this.hostLost,
    this.onTakeOverHost,
    this.onResync,
  });

  final GameBloc bloc;
  final VoidCallback? onClose;
  final String? roomCode;
  final int roomStake;
  final bool isHost;
  final Stream<Emote>? emotes;
  final ValueChanged<String>? onEmote;
  final ValueChanged<bool>? onBackground;
  final ValueListenable<bool>? hostLost;
  final VoidCallback? onTakeOverHost;
  final VoidCallback? onResync;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _prev = widget.bloc.state;
    _sub = widget.bloc.stream.listen(_onState);
    _emoteSub = widget.emotes?.listen(_onEmote);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    _emoteSub?.cancel();
    for (final t in _bubbleTimers.values) {
      t.cancel();
    }
    widget.bloc.close();
    widget.onClose?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 1. كتم الصوت فوراً ومنع أي مؤثرات صوتية أثناء قفل الشاشة أو الخلفية
    SoundService.instance.onAppLifecycleChanged(state);

    final inBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;

    if (inBackground) {
      // 2. تفعيل البوت فوراً ليلعب بدلاً من اللاعب بدون إيقاف أو تأخير المباراة
      final me = widget.bloc.localSeat;
      if (!widget.bloc.state.autoSeats.contains(me)) {
        widget.bloc.add(const AutoPlayToggled(enabled: true));
      }
      widget.onBackground?.call(true);
    } else if (state == AppLifecycleState.resumed) {
      // 3. عند فتح القفل والعودة للعبة: استعادة التحكم اليدوي وتحديث الحالة
      final me = widget.bloc.localSeat;
      if (widget.bloc.state.autoSeats.contains(me)) {
        widget.bloc.add(const AutoPlayToggled(enabled: false));
      }
      widget.onBackground?.call(false);
      widget.onResync?.call();
    }
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
      if (s.lastTrickWinner != null &&
          Rules.teamOf(s.lastTrickWinner!) == lt) {
        sfx.impact();
      }
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

      // اللعب نظيف وبدون أي جوائز أو مراهنات نقاط - لا يتم توزيع أي أرباح للفائز
      try {
        context.read<AuthCubit>().refreshCoins();
      } catch (_) {}
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
            : (widget.roomStake > 0
                ? 'تنبيه: الخروج أثناء المباراة يعني خسارة رسم الدخول (${widget.roomStake} نقطة) وسيكمل البوت مكانك.'
                : 'سيلعب البوت مكانك لتكمل اللعبة بدونك.'),
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
                        onResync: widget.onResync,
                        roomCode: widget.roomCode,
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
                    if (widget.roomCode != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: ConnectivityService.instance.isOnlineNotifier,
                        builder: (context, isOnline, _) {
                          if (isOnline) return const SizedBox.shrink();
                          return Positioned(
                            top: 50,
                            left: 20,
                            right: 20,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xEE92400E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFBBF24),
                                    width: 1.2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wifi_off_rounded,
                                      color: Color(0xFFFDE68A),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'انقطع الاتصال بالإنترنت... البوت يلعب بدلاً منك لحين عودة الاتصال',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    this.onResync,
    this.roomCode,
  });

  final GameState state;
  final int me;
  final ValueNotifier<Map<int, String>> bubbles;
  final VoidCallback? onEmoteTap;
  final VoidCallback? onResync;
  final String? roomCode;

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
            // 1. طاولة الديوانية الكويتية الوسطية (ساحة رمي الأوراق)
            Positioned(
              key: const ValueKey('trick_arena'),
              top: isPortrait ? 128 : 48,
              bottom: isPortrait ? 184 : 74,
              left: isPortrait ? 68 : 92,
              right: isPortrait ? 68 : 92,
              child: TrickArena(state: s, me: me),
            ),

            // 1ب. نافذة مصغرة لآخر أكلة (أعلى اليسار تحت شريط التحكم كما في الألعاب العالمية)
            if (s.lastTrick.isNotEmpty)
              Positioned(
                key: const ValueKey('mini_last_trick'),
                top: isPortrait ? 48 : 44,
                left: 10,
                child: MiniLastTrickBox(state: s, me: me),
              ),

            // 2. شريط التحكم والنقاط الموحد والمتجاوب (يمنع أي تداخل نهائياً)
            Positioned(
              key: const ValueKey('game_top_bar'),
              top: 6,
              left: isPortrait ? 8 : 12,
              right: isPortrait ? 8 : 12,
              child: GameTopBar(
                state: s,
                me: me,
                onResync: onResync,
                isPortrait: isPortrait,
                roomCode: roomCode,
              ),
            ),

            // 4. محطة الشريك
            Positioned(
              key: const ValueKey('partner_station'),
              top: isPortrait ? 54 : 4,
              left: 0,
              right: 0,
              child: Center(
                child: PartnerStation(state: s, seat: partnerSeat),
              ),
            ),

            // 5. مؤشر المرحلة والدور المباشر (أو شريط اللعب التلقائي في مساحة حرة بدون تغطية أي ورق)
            if (!finished && s.phase != GamePhase.idle)
              Positioned(
                key: const ValueKey('phase_status'),
                top: isPortrait ? 99 : null,
                bottom: isPortrait ? null : (onEmoteTap != null ? 54 : 10),
                left: isPortrait ? 0 : null,
                right: isPortrait ? 0 : 6,
                child: isPortrait
                    ? Center(
                        child: isAuto
                            ? const AutoPlayBanner()
                            : PhaseStatusTicker(state: s, me: me),
                      )
                    : (isAuto
                        ? const AutoPlayBanner(compact: true)
                        : PhaseStatusTicker(state: s, me: me, compact: true)),
              ),

            // 6. محطة الخصم الأيمن (خارج إطار الطاولة)
            Positioned(
              key: const ValueKey('right_station'),
              right: isPortrait ? 4 : 8,
              top: isPortrait ? 126 : 48,
              bottom: isPortrait ? 184 : 74,
              child: Center(
                child: SideStation(state: s, seat: rightSeat, isRight: true),
              ),
            ),

            // 7. محطة الخصم الأيسر (خارج إطار الطاولة)
            Positioned(
              key: const ValueKey('left_station'),
              left: isPortrait ? 4 : 8,
              top: isPortrait ? 126 : 48,
              bottom: isPortrait ? 184 : 74,
              child: Center(
                child: SideStation(state: s, seat: leftSeat, isRight: false),
              ),
            ),

            // 8. محطة اللاعب (أنت)
            Positioned(
              key: const ValueKey('player_station'),
              left: 10,
              bottom: isPortrait ? 124 : 8,
              child: PlayerStation(state: s, seat: me),
            ),

            // 9. زر الدردشة
            if (onEmoteTap != null)
              Positioned(
                key: const ValueKey('emote_btn'),
                right: 10,
                bottom: isPortrait ? 124 : 8,
                child: EmoteButton(onTap: onEmoteTap!),
              ),

            // 10. يد اللاعب في المنتصف أسفل الشاشة
            Positioned(
              key: const ValueKey('hand_view'),
              bottom: isPortrait ? 4 : 0,
              left: 0,
              right: 0,
              child: HandView(state: s, me: me, isPortrait: isPortrait),
            ),

            // 11. فقاعات الدردشة العائمة
            ValueListenableBuilder<Map<int, String>>(
              key: const ValueKey('bubbles_layer'),
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
                key: ValueKey('idle_overlay'),
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
                key: const ValueKey('bid_panel'),
                alignment: Alignment(0, isPortrait ? 0.0 : -0.18),
                child: BidPanel(state: s),
              ),
            if (humanTrump)
              Align(
                key: const ValueKey('trump_picker'),
                alignment: Alignment(0, isPortrait ? 0.0 : -0.18),
                child: const TrumpPicker(),
              ),
            if (finished)
              ResultOverlay(
                key: const ValueKey('result_overlay'),
                state: s,
              ),
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
