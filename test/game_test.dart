import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kout_bo4/bloc/game_bloc.dart';
import 'package:kout_bo4/bloc/game_codec.dart';
import 'package:kout_bo4/domain/card.dart';
import 'package:kout_bo4/domain/deck.dart';
import 'package:kout_bo4/domain/rules.dart';

PlayedCard p(int player, PlayingCard card) =>
    PlayedCard(player: player, card: card);

void main() {
  group('Deck', () {
    test('36 cards, no red sixes, two jokers', () {
      final deck = Deck.build();
      expect(deck.length, 36);
      expect(deck.toSet().length, 36);
      expect(deck.contains(const PlayingCard.suited(Suit.hearts, Rank.six)), isFalse);
      expect(deck.contains(const PlayingCard.suited(Suit.diamonds, Rank.six)), isFalse);
      expect(deck.contains(const PlayingCard.suited(Suit.spades, Rank.six)), isTrue);
      expect(deck.where((c) => c.isJoker).length, 2);
    });

    test('deal gives 9 unique cards to each of 4 players', () {
      final hands = Deck.deal(Random(7));
      expect(hands.length, 4);
      expect(hands.every((h) => h.length == 9), isTrue);
      expect(hands.expand((h) => h).toSet().length, 36);
    });
  });

  group('Rules', () {
    const trump = Suit.spades;

    test('trump ace beats black joker; red joker beats everything', () {
      var trick = const Trick();
      trick = trick.add(p(0, const PlayingCard.suited(Suit.hearts, Rank.king)));
      trick = trick.add(p(1, const PlayingCard.suited(Suit.spades, Rank.ace)));
      trick = trick.add(p(2, const PlayingCard.joker(JokerKind.black)));
      trick = trick.add(p(3, const PlayingCard.suited(Suit.hearts, Rank.ace)));
      expect(Rules.trickWinner(trick, trump), 1);

      final withRed = trick.plays.take(3).toList();
      var t2 = const Trick();
      for (final pl in withRed) {
        t2 = t2.add(pl);
      }
      t2 = t2.add(p(3, const PlayingCard.joker(JokerKind.red)));
      expect(Rules.trickWinner(t2, trump), 3);
    });

    test('must follow suit but jokers are always allowed', () {
      final trick = const Trick()
          .add(p(3, const PlayingCard.suited(Suit.hearts, Rank.queen)));
      const hand = [
        PlayingCard.suited(Suit.hearts, Rank.king),
        PlayingCard.suited(Suit.spades, Rank.seven),
        PlayingCard.joker(JokerKind.red),
      ];
      final legal = Rules.legalPlays(
        hand: hand,
        trick: trick,
        trump: trump,
        bid: 6,
        player: 0,
        bidderTeam: 1,
        playedCards: const [],
      );
      expect(legal.length, 2);
      expect(legal.contains(const PlayingCard.suited(Suit.spades, Rank.seven)), isFalse);
    });

    test('joker lead permissions', () {
      const red = PlayingCard.joker(JokerKind.red);
      const black = PlayingCard.joker(JokerKind.black);
      bool can(PlayingCard c, int bid, bool team) => Rules.canLeadJoker(
            card: c,
            trump: trump,
            bid: bid,
            onBidderTeam: team,
            playedCards: const [],
          );
      expect(can(red, 6, true), isFalse);
      expect(can(red, 8, true), isTrue);
      expect(can(black, 8, true), isFalse);
      expect(can(black, 9, true), isTrue);
      expect(can(red, 9, false), isFalse);
    });

    test('forced joker lead: cancelled second joker, third card sets suit', () {
      var trick = const Trick()
          .add(p(0, const PlayingCard.joker(JokerKind.black)), forcedLead: true);
      trick = trick.add(p(1, const PlayingCard.joker(JokerKind.red)));
      trick = trick.add(p(2, const PlayingCard.suited(Suit.diamonds, Rank.seven)));
      trick = trick.add(p(3, const PlayingCard.suited(Suit.diamonds, Rank.nine)));
      expect(Rules.leadSuit(trick, trump), Suit.diamonds);
      expect(Rules.trickWinner(trick, trump), 3);
    });
  });


  group('GameCodec', () {
    test('encode/decode keeps own hand and hides others', () {
      final hands = Deck.deal(Random(3));
      final s = GameState(
        phase: GamePhase.playing,
        hands: hands,
        bids: const [5, 0, 0, 0],
        highestBid: 5,
        bidder: 0,
        trump: Suit.hearts,
        trick: Trick(plays: [p(0, hands[0].first)]),
        names: const ['أ', 'ب', 'ج', 'د'],
        startedAt: DateTime(2026, 1, 1),
      );
      final back = GameCodec.decode(GameCodec.encode(s, forSeat: 1));
      expect(back.hands[1], hands[1]);
      expect(back.hands[0].length, 9);
      expect(back.hands[0], isNot(hands[0]));
      expect(back.trump, Suit.hearts);
      expect(back.trick.plays.length, 1);
      expect(back.names, ['أ', 'ب', 'ج', 'د']);
    });

    test('actions round-trip', () {
      const card = PlayingCard.suited(Suit.clubs, Rank.jack);
      final json = GameCodec.actionToJson(const CardPlayed(card), 2);
      final e = GameCodec.actionFromJson(json) as CardPlayed;
      expect(e.card, card);
      expect(e.seat, 2);
    });
  });

  group('GameBloc', () {
    test('GameStarted deals a round and starts bidding', () async {
      final bloc = GameBloc(
        random: Random(1),
        botDelay: Duration.zero,
        trickDelay: Duration.zero,
      );
      bloc.add(const GameStarted());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.roundNumber, 1);
      expect(bloc.state.phase, isNot(GamePhase.idle));
      expect(bloc.state.scores, [0, 0]);
      await bloc.close();
    });

    test('all-bot game runs to completion with valid scores', () async {
      final bloc = GameBloc(
        random: Random(5),
        humanSeats: <int>{},
        botDelay: Duration.zero,
        trickDelay: Duration.zero,
      );
      bloc.add(const GameStarted());
      GameState last = bloc.state;
      for (var i = 0; i < 80; i++) {
        last = await bloc.stream
            .firstWhere((s) =>
                s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver)
            .timeout(const Duration(seconds: 20));
        if (last.phase == GamePhase.gameOver) break;
        bloc.add(const NextRoundRequested());
      }
      expect(last.phase, GamePhase.gameOver);
      expect(last.winnerTeam, isNotNull);
      expect(last.scores.reduce((a, b) => a + b), greaterThan(0));
      expect(last.endedAt, isNotNull);
      await bloc.close();
    });
  });
}
