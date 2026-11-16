import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config.dart';
import '../domain/bot_strategy.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/rules.dart';

part 'game_event.dart';
part 'game_state.dart';

/// يُرسل حدثاً من لاعب بعيد إلى المضيف.
typedef ActionSender = void Function(GameEvent event);

/// ينشر الحالة (المضيف) لباقي اللاعبين.
typedef StatePublisher = void Function(GameState state);

/// المقاعد 0..3 بعكس عقارب الساعة. الفريق = المقعد % 2.
///
/// أوضاع التشغيل:
///  - محلي: `humanSeats = {0}` والباقي بوتات.
///  - مضيف أونلاين: `humanSeats` = مقاعد اللاعبين الحقيقيين، ويستقبل أفعالهم.
///  - لاعب بعيد: `remote = true`، يرسل أفعاله للمضيف ويستقبل الحالة منه.
class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({
    Random? random,
    this.localSeat = 0,
    Set<int>? humanSeats,
    this.remote = false,
    this.turnSeconds = 0,
    this.matchMinutes = 0,
    this.targetScore = 101,
    this.botDifficulty = BotDifficulty.normal,
    List<String>? names,
    this.botDelay = const Duration(milliseconds: 800),
    this.trickDelay = const Duration(milliseconds: 1450),
  })  : humanSeats = humanSeats ?? {localSeat},
        names = names ?? const ['أنت', 'خصم ١', 'شريكك', 'خصم ٢'],
        _rng = random ?? Random(),
        super(const GameState()) {
    on<GameStarted>(_onStarted);
    on<BidPlaced>(_onBid);
    on<TrumpChosen>(_onTrump);
    on<CardPlayed>(_onCard);
    on<NextRoundRequested>(_onNextRound);
    on<TurnTimedOut>(_onTimeout);
    on<SeatLeft>(_onSeatLeft);
    on<AutoPlayToggled>(_onAutoPlayToggled);
    on<MatchTimedOut>(_onMatchTimedOut);
    on<MatchTimeExtended>(_onMatchTimeExtended);
    on<HostMigrated>(_onHostMigrated);
    on<StateReceived>((e, emit) => emit(e.state));
  }

  final int localSeat;
  final Set<int> humanSeats;
  bool remote;
  final int turnSeconds;
  final int matchMinutes;
  final int targetScore;
  final BotDifficulty botDifficulty;
  final List<String> names;
  final Duration botDelay;
  final Duration trickDelay;
  final Random _rng;

  ActionSender? sendAction;
  StatePublisher? publishState;

  /// مقاعد بشرية انتهت مهلتها فيلعب عنها البوت حتى تعود للتصرف.
  final Set<int> _autoSeats = {};

  /// مقاعد غادرها أصحابها نهائياً.
  final Set<int> _leftSeats = {};
  Timer? _turnTimer;
  Timer? _matchTimer;

  /// يزداد مع كل لعبة جديدة لإيقاف أي حلقة بوتات قديمة.
  int _epoch = 0;

  bool _isHuman(int seat) =>
      humanSeats.contains(seat) &&
      !_autoSeats.contains(seat) &&
      !_leftSeats.contains(seat);

  int get localTeam => Rules.teamOf(localSeat);

  // ───────────────────────── المؤقت والنشر ─────────────────────────

  @override
  void onChange(Change<GameState> change) {
    super.onChange(change);
    final s = change.nextState;
    publishState?.call(s);
    if (remote) return;
    if (s.turnEndsAt != change.currentState.turnEndsAt) {
      _turnTimer?.cancel();
      final end = s.turnEndsAt;
      final actor = s.actor;
      if (end != null && actor != null) {
        final wait = end.difference(DateTime.now());
        _turnTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
          if (!isClosed) add(TurnTimedOut(seat: actor, deadline: end));
        });
      }
    }
  }

  @override
  Future<void> close() {
    _turnTimer?.cancel();
    _matchTimer?.cancel();
    return super.close();
  }

  /// يضبط موعد انتهاء مهلة الدور حسب من عليه الدور ويحدّث حالة اللعب التلقائي.
  GameState _stamp(GameState s) {
    final actor = s.actor;
    final synced = s.copyWith(autoSeats: Set.unmodifiable(_autoSeats));
    if (!remote && turnSeconds > 0 && actor != null && _isHuman(actor)) {
      return synced.copyWith(
        turnEndsAt: DateTime.now().add(Duration(seconds: turnSeconds)),
      );
    }
    return synced.copyWith(turnEndsAt: null);
  }

  // ───────────────────────── الأحداث ─────────────────────────

  Future<void> _onStarted(GameStarted event, Emitter<GameState> emit) async {
    if (remote) {
      sendAction?.call(const GameStarted());
      return;
    }
    _epoch++;
    _autoSeats.clear();
    _matchTimer?.cancel();
    final now = DateTime.now();
    final matchEnd =
        matchMinutes > 0 ? now.add(Duration(minutes: matchMinutes)) : null;
    if (matchEnd != null) {
      _matchTimer = Timer(Duration(minutes: matchMinutes), () {
        if (!isClosed) add(const MatchTimedOut());
      });
    }
    emit(_stamp(_newRound(
      scores: const [0, 0],
      roundNumber: 1,
      dealer: _rng.nextInt(4),
      startedAt: now,
    ).copyWith(matchEndsAt: matchEnd)));
    await _runBots(emit);
  }

  Future<void> _onHostMigrated(
    HostMigrated event,
    Emitter<GameState> emit,
  ) async {
    remote = false;
    sendAction = null;
    _epoch++;
    _leftSeats.add(event.oldHostSeat);
    _autoSeats.remove(event.oldHostSeat);
    emit(_stamp(event.fullState));
    await _runBots(emit);
  }

  void _endByMatchTimeout(Emitter<GameState> emit) {
    _epoch++;
    _turnTimer?.cancel();
    _matchTimer?.cancel();
    final winner = state.scores[0] >= state.scores[1] ? 0 : 1;
    emit(state.copyWith(
      phase: GamePhase.gameOver,
      winnerTeam: winner,
      endedAt: DateTime.now(),
      turnEndsAt: null,
    ));
  }

  void _onMatchTimedOut(MatchTimedOut event, Emitter<GameState> emit) {
    if (remote ||
        state.phase == GamePhase.idle ||
        state.phase == GamePhase.gameOver) {
      return;
    }
    _endByMatchTimeout(emit);
  }

  void _onMatchTimeExtended(
    MatchTimeExtended event,
    Emitter<GameState> emit,
  ) {
    if (remote) {
      sendAction?.call(event);
      return;
    }
    final now = DateTime.now();
    final currentEnd = state.matchEndsAt;
    final base = (currentEnd != null && currentEnd.isAfter(now))
        ? currentEnd
        : now;
    final newEnd = base.add(Duration(minutes: event.additionalMinutes));

    _matchTimer?.cancel();
    final remaining = newEnd.difference(now);
    if (remaining > Duration.zero) {
      _matchTimer = Timer(remaining, () {
        if (!isClosed) add(const MatchTimedOut());
      });
    }

    emit(_stamp(state.copyWith(matchEndsAt: newEnd)));
  }

  Future<void> _onNextRound(
    NextRoundRequested event,
    Emitter<GameState> emit,
  ) async {
    if (remote) {
      sendAction?.call(const NextRoundRequested());
      return;
    }
    if (state.phase != GamePhase.roundOver) return;
    final matchEnd = state.matchEndsAt;
    if (matchEnd != null && !DateTime.now().isBefore(matchEnd)) {
      _endByMatchTimeout(emit);
      return;
    }
    emit(_stamp(_newRound(
      scores: state.scores,
      roundNumber: state.roundNumber + 1,
      dealer: (state.dealer + 1) % 4,
      startedAt: state.startedAt,
      matchEndsAt: matchEnd,
      roundHistory: state.roundHistory,
    )));
    await _runBots(emit);
  }

  Future<void> _onBid(BidPlaced event, Emitter<GameState> emit) async {
    if (remote) {
      sendAction?.call(event);
      return;
    }
    final seat = event.seat ?? localSeat;
    final s = state;
    if (s.phase != GamePhase.bidding ||
        s.currentPlayer != seat ||
        !humanSeats.contains(seat)) {
      return;
    }
    if (event.bid != 0 &&
        (event.bid < s.minAllowedBid || event.bid > Rules.maxBid)) {
      return;
    }
    _autoSeats.remove(seat);
    emit(_stamp(_applyBid(s, seat, event.bid)));
    await _runBots(emit);
  }

  Future<void> _onTrump(TrumpChosen event, Emitter<GameState> emit) async {
    if (remote) {
      sendAction?.call(event);
      return;
    }
    final seat = event.seat ?? localSeat;
    final s = state;
    if (s.phase != GamePhase.chooseTrump ||
        s.bidder != seat ||
        !humanSeats.contains(seat)) {
      return;
    }
    _autoSeats.remove(seat);
    emit(_stamp(_applyTrump(s, event.suit)));
    await _runBots(emit);
  }

  Future<void> _onCard(CardPlayed event, Emitter<GameState> emit) async {
    if (remote) {
      sendAction?.call(event);
      return;
    }
    final seat = event.seat ?? localSeat;
    final s = state;
    if (s.phase != GamePhase.playing ||
        s.currentPlayer != seat ||
        s.trick.isComplete ||
        !humanSeats.contains(seat)) {
      return;
    }
    if (!s.legalMoves(seat).contains(event.card)) return;
    _autoSeats.remove(seat);
    emit(_stamp(_applyPlay(s, seat, event.card)));
    await _runBots(emit);
  }

  Future<void> _onTimeout(TurnTimedOut event, Emitter<GameState> emit) async {
    if (remote) return;
    final s = state;
    if (s.turnEndsAt != event.deadline || s.actor != event.seat) return;
    _autoSeats.add(event.seat);
    emit(s.copyWith(
      turnEndsAt: null,
      autoSeats: Set.unmodifiable(_autoSeats),
    ));
    await _runBots(emit);
  }

  Future<void> _onSeatLeft(SeatLeft event, Emitter<GameState> emit) async {
    if (remote) return;
    _leftSeats.add(event.seat);
    final s = state;
    if (s.actor == event.seat) {
      emit(s.copyWith(turnEndsAt: null));
      await _runBots(emit);
    }
  }

  Future<void> _onAutoPlayToggled(
    AutoPlayToggled event,
    Emitter<GameState> emit,
  ) async {
    if (remote) {
      sendAction?.call(event);
      return;
    }
    final seat = event.seat ?? localSeat;
    if (!humanSeats.contains(seat)) return;
    if (event.enabled) {
      _autoSeats.add(seat);
      emit(state.copyWith(
        autoSeats: Set.unmodifiable(_autoSeats),
        turnEndsAt: state.actor == seat ? null : state.turnEndsAt,
      ));
      if (state.actor == seat) {
        await _runBots(emit);
      }
    } else {
      _autoSeats.remove(seat);
      emit(_stamp(state));
    }
  }

  // ───────────────────── حلقة اللاعبين الآليين ─────────────────────

  Future<void> _runBots(Emitter<GameState> emit) async {
    final epoch = _epoch;
    bool cancelled() => emit.isDone || epoch != _epoch;

    while (!cancelled()) {
      final s = state;
      final matchEnd = s.matchEndsAt;
      if (matchEnd != null &&
          !DateTime.now().isBefore(matchEnd) &&
          s.phase != GamePhase.idle &&
          s.phase != GamePhase.gameOver) {
        _endByMatchTimeout(emit);
        return;
      }
      switch (s.phase) {
        case GamePhase.bidding:
          {
            if (_isHuman(s.currentPlayer)) return;
            await Future<void>.delayed(botDelay);
            if (cancelled()) return;
            if (!identical(state, s)) continue;
            final p = s.currentPlayer;
            final bid = BotStrategy.chooseBid(
              hand: s.hands[p],
              highestBid: s.highestBid,
            );
            emit(_stamp(_applyBid(s, p, bid)));
            break;
          }

        case GamePhase.chooseTrump:
          {
            if (_isHuman(s.bidder!)) return;
            await Future<void>.delayed(botDelay);
            if (cancelled()) return;
            if (!identical(state, s)) continue;
            final suit = BotStrategy.chooseTrump(s.hands[s.bidder!]);
            emit(_stamp(_applyTrump(s, suit)));
            break;
          }

        case GamePhase.playing:
          {
            if (s.trick.isComplete) {
              await Future<void>.delayed(trickDelay);
              if (cancelled()) return;
              if (!identical(state, s)) continue;
              emit(_stamp(_resolveTrick(s)));
              break;
            }
            if (_isHuman(s.currentPlayer)) return;
            await Future<void>.delayed(botDelay);
            if (cancelled()) return;
            if (!identical(state, s)) continue;
            final p = s.currentPlayer;
            final card = BotStrategy.chooseCard(
              legal: s.legalMoves(p),
              trick: s.trick,
              trump: s.trump!,
              player: p,
              bidderTeam: s.bidderTeam!,
              difficulty: botDifficulty,
              playedCards: s.playedCards,
            );
            emit(_stamp(_applyPlay(s, p, card)));
            break;
          }

        case GamePhase.idle:
        case GamePhase.roundOver:
        case GamePhase.gameOver:
          return;
      }
    }
  }

  // ───────────────────── منطق الحالة (نقي) ─────────────────────

  GameState _newRound({
    required List<int> scores,
    required int roundNumber,
    required int dealer,
    required DateTime? startedAt,
    DateTime? matchEndsAt,
    List<RoundResult> roundHistory = const [],
  }) {
    return GameState(
      phase: GamePhase.bidding,
      hands: Deck.deal(_rng),
      dealer: dealer,
      // المزايدة تبدأ باللاعب التالي للموزع (على يمينه) بعكس عقارب الساعة.
      currentPlayer: (dealer + 1) % 4,
      scores: scores,
      roundNumber: roundNumber,
      names: names,
      targetScore: targetScore,
      startedAt: startedAt,
      matchEndsAt: matchEndsAt,
      roundHistory: roundHistory,
    );
  }

  GameState _applyBid(GameState s, int player, int bid) {
    var effective = bid;
    var forced = false;
    // الموزع آخر من يزايد؛ إن مرر الجميع قبله فهو "ملزوم" بـ 5.
    if (bid == 0 && player == s.dealer && s.highestBid == 0) {
      effective = Rules.minBid;
      forced = true;
    }
    final bids = List<int?>.of(s.bids);
    bids[player] = effective;
    final highest = effective > 0 ? effective : s.highestBid;
    final bidder = effective > 0 ? player : s.bidder;
    final done = bids.every((b) => b != null) || effective >= Rules.maxBid;

    if (!done) {
      return s.copyWith(
        bids: bids,
        highestBid: highest,
        bidder: bidder,
        currentPlayer: (player + 1) % 4,
      );
    }
    return s.copyWith(
      bids: bids,
      highestBid: highest,
      bidder: bidder,
      forcedBid: forced,
      phase: GamePhase.chooseTrump,
      currentPlayer: bidder!,
    );
  }

  GameState _applyTrump(GameState s, Suit suit) {
    return s.copyWith(
      trump: suit,
      phase: GamePhase.playing,
      currentPlayer: s.bidder!,
    );
  }

  GameState _applyPlay(GameState s, int player, PlayingCard card) {
    final hands = [for (final h in s.hands) List<PlayingCard>.of(h)];
    hands[player].remove(card);

    final isLead = s.trick.plays.isEmpty;
    final forced = isLead &&
        card.isJoker &&
        !Rules.canLeadJoker(
          card: card,
          trump: s.trump!,
          bid: s.highestBid,
          onBidderTeam: Rules.teamOf(player) == s.bidderTeam,
          playedCards: s.playedCards,
        );
    final trick = s.trick.add(
      PlayedCard(player: player, card: card),
      forcedLead: forced,
    );
    return s.copyWith(
      hands: hands,
      trick: trick,
      currentPlayer: trick.isComplete ? player : (player + 1) % 4,
    );
  }

  GameState _resolveTrick(GameState s) {
    final winner = Rules.trickWinner(s.trick, s.trump!);
    final winTeam = Rules.teamOf(winner);
    final won = List<int>.of(s.tricksWon);
    won[winTeam] += 1;
    final played = [...s.playedCards, ...s.trick.plays.map((p) => p.card)];

    final bidderTeam = s.bidderTeam!;
    final oppTeam = 1 - bidderTeam;
    final bid = s.highestBid;
    final bidderDone = won[bidderTeam] >= bid;
    final bidderFailed = won[oppTeam] > Rules.handSize - bid;

    final next = s.copyWith(
      tricksWon: won,
      playedCards: played,
      trick: const Trick(),
      currentPlayer: winner,
      lastTrickWinner: winner,
      lastTrick: s.trick.plays,
    );
    if (!bidderDone && !bidderFailed) return next;
    return _finishRound(next, success: bidderDone);
  }

  GameState _finishRound(GameState s, {required bool success}) {
    final bidderTeam = s.bidderTeam!;
    final bid = s.highestBid;
    final scores = List<int>.of(s.scores);

    final int scoringTeam;
    final int points;
    if (success) {
      scoringTeam = bidderTeam;
      points = bid == Rules.maxBid ? 36 : bid; // "باون" ناجحة = 36
    } else {
      scoringTeam = 1 - bidderTeam;
      points = s.forcedBid ? 5 : bid * 2; // "ملزوم" فاشلة = 5 فقط
    }
    scores[scoringTeam] += points;

    final target = s.targetScore;
    final shutout = (target + 1) ~/ 2; // 101 → 51
    int? winner;
    for (var t = 0; t < 2; t++) {
      if (scores[t] >= target || (scores[t] >= shutout && scores[1 - t] == 0)) {
        winner = t;
      }
    }
    if (winner == null &&
        success &&
        bid == Rules.maxBid &&
        s.roundNumber == 1) {
      winner = bidderTeam; // باون ناجحة في أول جولة
    }

    final result = RoundResult(
      bidderTeam: bidderTeam,
      bid: bid,
      forced: s.forcedBid,
      success: success,
      scoringTeam: scoringTeam,
      points: points,
    );
    return s.copyWith(
      scores: scores,
      phase: winner == null ? GamePhase.roundOver : GamePhase.gameOver,
      winnerTeam: winner,
      endedAt: winner == null ? null : DateTime.now(),
      result: result,
      roundHistory: [...s.roundHistory, result],
    );
  }
}
