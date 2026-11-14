import 'dart:math';

import 'card.dart';

class Deck {
  Deck._();

  static List<PlayingCard> build() {
    final cards = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        if (rank == Rank.six && suit.isRed) continue;
        cards.add(PlayingCard.suited(suit, rank));
      }
    }
    cards.add(const PlayingCard.joker(JokerKind.red));
    cards.add(const PlayingCard.joker(JokerKind.black));
    return cards;
  }

  static List<List<PlayingCard>> deal(Random rng) {
    final deck = build()..shuffle(rng);
    return [
      for (var i = 0; i < 4; i++) sortHand(deck.sublist(i * 9, i * 9 + 9)),
    ];
  }

  static List<PlayingCard> sortHand(List<PlayingCard> hand) {
    int key(PlayingCard c) {
      if (c.isJoker) return c.isRedJoker ? -2000 : -1000;
      return c.suit!.index * 100 - c.rank!.value;
    }

    final sorted = List<PlayingCard>.of(hand);
    sorted.sort((a, b) => key(a).compareTo(key(b)));
    return sorted;
  }
}
