import '../domain/card.dart';
import '../domain/rules.dart';
import 'game_bloc.dart';

/// تحويل الحالة والأفعال إلى JSON للإرسال عبر Supabase Realtime.
class GameCodec {
  GameCodec._();

  /// ورقة وهمية تمثل أوراق اللاعبين الآخرين المخفية.
  static const hiddenCard = PlayingCard.joker(JokerKind.black);

  static String cardToJson(PlayingCard c) =>
      c.isJoker ? 'j${c.joker!.index}' : '${c.suit!.index}-${c.rank!.index}';

  static PlayingCard cardFromJson(String s) {
    if (s.startsWith('j')) {
      return PlayingCard.joker(JokerKind.values[int.parse(s.substring(1))]);
    }
    final p = s.split('-');
    return PlayingCard.suited(
      Suit.values[int.parse(p[0])],
      Rank.values[int.parse(p[1])],
    );
  }

  /// نسخة الحالة كما يراها المقعد [forSeat]: يده فقط مكشوفة.
  static Map<String, dynamic> encode(GameState s, {required int forSeat}) {
    final r = s.result;
    return {
      'seat': forSeat,
      'phase': s.phase.index,
      'hand': s.hands[forSeat].map(cardToJson).toList(),
      'counts': s.hands.map((h) => h.length).toList(),
      'dealer': s.dealer,
      'current': s.currentPlayer,
      'bids': s.bids,
      'highestBid': s.highestBid,
      'bidder': s.bidder,
      'forcedBid': s.forcedBid,
      'trump': s.trump?.index,
      'trick': {
        'plays': [
          for (final p in s.trick.plays) {'p': p.player, 'c': cardToJson(p.card)},
        ],
        'forced': s.trick.forcedJokerLead,
      },
      'tricksWon': s.tricksWon,
      'played': s.playedCards.map(cardToJson).toList(),
      'scores': s.scores,
      'round': s.roundNumber,
      'lastTrickWinner': s.lastTrickWinner,
      'lastTrick': [
        for (final p in s.lastTrick) {'p': p.player, 'c': cardToJson(p.card)},
      ],
      'result': r == null
          ? null
          : {
              'bt': r.bidderTeam,
              'bid': r.bid,
              'forced': r.forced,
              'ok': r.success,
              'st': r.scoringTeam,
              'pts': r.points,
            },
      'history': [
        for (final h in s.roundHistory)
          {
            'bt': h.bidderTeam,
            'bid': h.bid,
            'forced': h.forced,
            'ok': h.success,
            'st': h.scoringTeam,
            'pts': h.points,
          },
      ],
      'winner': s.winnerTeam,
      'names': s.names,
      'target': s.targetScore,
      'startedMs': s.startedAt?.millisecondsSinceEpoch,
      'endedMs': s.endedAt?.millisecondsSinceEpoch,
      // نرسل الزمن المتبقي لأن ساعات الأجهزة قد تختلف.
      'turnLeftMs': s.turnEndsAt?.difference(DateTime.now()).inMilliseconds,
      'matchLeftMs': s.matchEndsAt?.difference(DateTime.now()).inMilliseconds,
      'autoSeats': s.autoSeats.toList(),
    };
  }

  /// نسخة كاملة من الحالة لنقل الاستضافة (تتضمن أوراق كل اللاعبين).
  static Map<String, dynamic> encodeFull(GameState s, {required int forSeat}) =>
      encode(s, forSeat: forSeat)
        ..['allHands'] = s.hands.map((h) => h.map(cardToJson).toList()).toList();

  static GameState decode(Map<String, dynamic> j) {
    final seat = j['seat'] as int;
    final counts = (j['counts'] as List).cast<int>();
    final myHand =
        (j['hand'] as List).map((e) => cardFromJson(e as String)).toList();
    final allRaw = j['allHands'] as List?;
    final decodedHands = allRaw != null
        ? [
            for (final h in allRaw)
              (h as List).map((e) => cardFromJson(e as String)).toList(),
          ]
        : [
            for (var i = 0; i < 4; i++)
              i == seat ? myHand : List<PlayingCard>.filled(counts[i], hiddenCard),
          ];
    final res = j['result'] as Map?;
    final trick = j['trick'] as Map;
    final startedMs = j['startedMs'] as int?;
    final endedMs = j['endedMs'] as int?;
    final leftMs = j['turnLeftMs'] as int?;
    final matchLeftMs = j['matchLeftMs'] as int?;
    final lastTrickRaw = (j['lastTrick'] as List?) ?? const [];
    final historyRaw = (j['history'] as List?) ?? const [];

    return GameState(
      phase: GamePhase.values[j['phase'] as int],
      hands: decodedHands,
      dealer: j['dealer'] as int,
      currentPlayer: j['current'] as int,
      bids: (j['bids'] as List).map((e) => e as int?).toList(),
      highestBid: j['highestBid'] as int,
      bidder: j['bidder'] as int?,
      forcedBid: j['forcedBid'] as bool,
      trump: j['trump'] == null ? null : Suit.values[j['trump'] as int],
      trick: Trick(
        plays: [
          for (final p in (trick['plays'] as List))
            PlayedCard(
              player: (p as Map)['p'] as int,
              card: cardFromJson(p['c'] as String),
            ),
        ],
        forcedJokerLead: trick['forced'] as bool,
      ),
      tricksWon: (j['tricksWon'] as List).cast<int>(),
      playedCards: (j['played'] as List)
          .map((e) => cardFromJson(e as String))
          .toList(),
      scores: (j['scores'] as List).cast<int>(),
      roundNumber: j['round'] as int,
      lastTrickWinner: j['lastTrickWinner'] as int?,
      lastTrick: [
        for (final p in lastTrickRaw)
          PlayedCard(
            player: (p as Map)['p'] as int,
            card: cardFromJson(p['c'] as String),
          ),
      ],
      result: res == null
          ? null
          : RoundResult(
              bidderTeam: res['bt'] as int,
              bid: res['bid'] as int,
              forced: res['forced'] as bool,
              success: res['ok'] as bool,
              scoringTeam: res['st'] as int,
              points: res['pts'] as int,
            ),
      roundHistory: [
        for (final h in historyRaw)
          RoundResult(
            bidderTeam: (h as Map)['bt'] as int,
            bid: h['bid'] as int,
            forced: h['forced'] as bool,
            success: h['ok'] as bool,
            scoringTeam: h['st'] as int,
            points: h['pts'] as int,
          ),
      ],
      winnerTeam: j['winner'] as int?,
      names: (j['names'] as List).cast<String>(),
      targetScore: j['target'] as int,
      startedAt: startedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedMs),
      endedAt:
          endedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endedMs),
      turnEndsAt: leftMs == null
          ? null
          : DateTime.now().add(Duration(milliseconds: leftMs)),
      matchEndsAt: matchLeftMs == null
          ? null
          : DateTime.now().add(Duration(milliseconds: matchLeftMs)),
      autoSeats: (j['autoSeats'] as List?)?.cast<int>().toSet() ?? const {},
    );
  }

  // ───────────────────── الأفعال (لاعب بعيد → المضيف) ─────────────────────

  static Map<String, dynamic> actionToJson(GameEvent e, int seat) {
    if (e is BidPlaced) return {'seat': seat, 'kind': 'bid', 'v': e.bid};
    if (e is TrumpChosen) {
      return {'seat': seat, 'kind': 'trump', 'v': e.suit.index};
    }
    if (e is CardPlayed) {
      return {'seat': seat, 'kind': 'card', 'v': cardToJson(e.card)};
    }
    if (e is NextRoundRequested) return {'seat': seat, 'kind': 'next'};
    if (e is SeatLeft) return {'seat': seat, 'kind': 'leave'};
    if (e is AutoPlayToggled) return {'seat': seat, 'kind': 'auto', 'v': e.enabled};
    if (e is MatchTimeExtended) {
      return {'seat': seat, 'kind': 'extend', 'v': e.additionalMinutes};
    }
    return {'seat': seat, 'kind': 'restart'};
  }

  static GameEvent? actionFromJson(Map<String, dynamic> j) {
    final seat = j['seat'] as int;
    switch (j['kind']) {
      case 'bid':
        return BidPlaced(j['v'] as int, seat: seat);
      case 'trump':
        return TrumpChosen(Suit.values[j['v'] as int], seat: seat);
      case 'card':
        return CardPlayed(cardFromJson(j['v'] as String), seat: seat);
      case 'next':
        return NextRoundRequested(seat: seat);
      case 'leave':
        return SeatLeft(seat);
      case 'auto':
        return AutoPlayToggled(enabled: j['v'] as bool, seat: seat);
      case 'extend':
        return MatchTimeExtended(
          additionalMinutes: (j['v'] as num?)?.toInt() ?? 20,
          seat: seat,
        );
      case 'restart':
        return GameStarted(seat: seat);
    }
    return null;
  }
}
