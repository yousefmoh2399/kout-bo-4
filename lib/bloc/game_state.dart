part of 'game_bloc.dart';

enum GamePhase { idle, bidding, chooseTrump, playing, roundOver, gameOver }

class RoundResult extends Equatable {
  const RoundResult({
    required this.bidderTeam,
    required this.bid,
    required this.forced,
    required this.success,
    required this.scoringTeam,
    required this.points,
  });

  final int bidderTeam;
  final int bid;
  final bool forced;
  final bool success;
  final int scoringTeam;
  final int points;

  @override
  List<Object?> get props =>
      [bidderTeam, bid, forced, success, scoringTeam, points];
}

class GameState extends Equatable {
  const GameState({
    this.phase = GamePhase.idle,
    this.hands = const [[], [], [], []],
    this.dealer = 0,
    this.currentPlayer = 0,
    this.bids = const [null, null, null, null],
    this.highestBid = 0,
    this.bidder,
    this.forcedBid = false,
    this.trump,
    this.trick = const Trick(),
    this.tricksWon = const [0, 0],
    this.playedCards = const [],
    this.scores = const [0, 0],
    this.roundNumber = 0,
    this.lastTrickWinner,
    this.result,
    this.winnerTeam,
    this.names = const ['لاعب ١', 'لاعب ٢', 'لاعب ٣', 'لاعب ٤'],
    this.targetScore = 101,
    this.startedAt,
    this.endedAt,
    this.turnEndsAt,
  });

  final GamePhase phase;

  /// عند اللاعب البعيد: يد المقعد المحلي فقط حقيقية؛ باقي الأيدي أوراق
  /// "وهمية" بنفس العدد (تُستخدم لعرض عدد الأوراق فقط).
  final List<List<PlayingCard>> hands;
  final int dealer;
  final int currentPlayer;

  /// null = لم يزايد بعد، 0 = طاف، 5..9 = مزايدة.
  final List<int?> bids;
  final int highestBid;
  final int? bidder;

  /// المزايدة "ملزوم" (الجميع مرروا وأُجبر الموزع على 5).
  final bool forcedBid;
  final Suit? trump;
  final Trick trick;

  /// عدد اللمات لكل فريق (الفريق = رقم المقعد % 2).
  final List<int> tricksWon;
  final List<PlayingCard> playedCards;
  final List<int> scores;
  final int roundNumber;
  final int? lastTrickWinner;
  final RoundResult? result;
  final int? winnerTeam;

  final List<String> names;
  final int targetScore;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// موعد انتهاء مهلة الدور الحالي (null = بدون مؤقت).
  final DateTime? turnEndsAt;

  int? get bidderTeam => bidder == null ? null : Rules.teamOf(bidder!);

  int get minAllowedBid => max(Rules.minBid, highestBid + 1);

  /// الموزع هو آخر من يزايد، وإذا مرر الجميع قبله يُجبر على 5.
  bool get passAllowed => !(currentPlayer == dealer && highestBid == 0);

  /// المقعد المطلوب منه التصرف الآن (مزايدة / اختيار حكم / لعب ورقة).
  int? get actor {
    switch (phase) {
      case GamePhase.bidding:
        return currentPlayer;
      case GamePhase.chooseTrump:
        return bidder;
      case GamePhase.playing:
        return trick.isComplete ? null : currentPlayer;
      default:
        return null;
    }
  }

  Duration get elapsed =>
      (endedAt ?? DateTime.now()).difference(startedAt ?? DateTime.now());

  List<PlayingCard> legalMoves(int player) {
    if (phase != GamePhase.playing || trump == null || bidderTeam == null) {
      return const [];
    }
    return Rules.legalPlays(
      hand: hands[player],
      trick: trick,
      trump: trump!,
      bid: highestBid,
      player: player,
      bidderTeam: bidderTeam!,
      playedCards: playedCards,
    );
  }

  static const Object _unset = Object();

  GameState copyWith({
    GamePhase? phase,
    List<List<PlayingCard>>? hands,
    int? dealer,
    int? currentPlayer,
    List<int?>? bids,
    int? highestBid,
    Object? bidder = _unset,
    bool? forcedBid,
    Object? trump = _unset,
    Trick? trick,
    List<int>? tricksWon,
    List<PlayingCard>? playedCards,
    List<int>? scores,
    int? roundNumber,
    Object? lastTrickWinner = _unset,
    Object? result = _unset,
    Object? winnerTeam = _unset,
    List<String>? names,
    int? targetScore,
    Object? startedAt = _unset,
    Object? endedAt = _unset,
    Object? turnEndsAt = _unset,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      hands: hands ?? this.hands,
      dealer: dealer ?? this.dealer,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      bids: bids ?? this.bids,
      highestBid: highestBid ?? this.highestBid,
      bidder: identical(bidder, _unset) ? this.bidder : bidder as int?,
      forcedBid: forcedBid ?? this.forcedBid,
      trump: identical(trump, _unset) ? this.trump : trump as Suit?,
      trick: trick ?? this.trick,
      tricksWon: tricksWon ?? this.tricksWon,
      playedCards: playedCards ?? this.playedCards,
      scores: scores ?? this.scores,
      roundNumber: roundNumber ?? this.roundNumber,
      lastTrickWinner: identical(lastTrickWinner, _unset)
          ? this.lastTrickWinner
          : lastTrickWinner as int?,
      result: identical(result, _unset) ? this.result : result as RoundResult?,
      winnerTeam:
          identical(winnerTeam, _unset) ? this.winnerTeam : winnerTeam as int?,
      names: names ?? this.names,
      targetScore: targetScore ?? this.targetScore,
      startedAt:
          identical(startedAt, _unset) ? this.startedAt : startedAt as DateTime?,
      endedAt: identical(endedAt, _unset) ? this.endedAt : endedAt as DateTime?,
      turnEndsAt: identical(turnEndsAt, _unset)
          ? this.turnEndsAt
          : turnEndsAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        hands,
        dealer,
        currentPlayer,
        bids,
        highestBid,
        bidder,
        forcedBid,
        trump,
        trick,
        tricksWon,
        playedCards,
        scores,
        roundNumber,
        lastTrickWinner,
        result,
        winnerTeam,
        names,
        targetScore,
        startedAt,
        endedAt,
        turnEndsAt,
      ];
}
