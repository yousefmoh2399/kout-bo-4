import 'dart:math';

import '../core/config.dart';
import 'card.dart';
import 'rules.dart';

/// ذكاء اصطناعي بسيط للاعبين الآليين.
class BotStrategy {
  BotStrategy._();

  static double _rankWeight(Rank r) {
    switch (r) {
      case Rank.ace:
        return 1.0;
      case Rank.king:
        return 0.7;
      case Rank.queen:
        return 0.45;
      case Rank.jack:
        return 0.3;
      default:
        return 0.1;
    }
  }

  static double _suitValue(List<PlayingCard> hand, Suit suit) {
    final cards = hand.where((c) => c.suit == suit).toList();
    var v = 0.0;
    for (final c in cards) {
      v += _rankWeight(c.rank!);
    }
    if (cards.length > 2) v += (cards.length - 2) * 0.5;
    return v;
  }

  static Suit chooseTrump(List<PlayingCard> hand) {
    var best = Suit.spades;
    var bestValue = -1.0;
    for (final s in Suit.values) {
      final v = _suitValue(hand, s);
      if (v > bestValue) {
        bestValue = v;
        best = s;
      }
    }
    return best;
  }

  /// يرجع 0 للتمرير (طاف) أو رقم المزايدة (5..9).
  static int chooseBid({required List<PlayingCard> hand, required int highestBid}) {
    final trump = chooseTrump(hand);
    final jokers = hand.where((c) => c.isJoker).length;
    final sideAces =
        hand.where((c) => c.rank == Rank.ace && c.suit != trump).length;
    final estimate = jokers + _suitValue(hand, trump) + sideAces * 0.6 + 1.2;
    final bid = min(Rules.maxBid, estimate.floor());
    if (bid < Rules.minBid || bid <= highestBid) return 0;
    return bid;
  }

  static int _cost(PlayingCard c, Suit trump) {
    if (c.isJoker) return c.isRedJoker ? 1100 : 1000;
    if (c.suit == trump) return 500 + c.rank!.value;
    return c.rank!.value;
  }

  static PlayingCard _cheapest(List<PlayingCard> cards, Suit trump) {
    return cards.reduce((a, b) => _cost(a, trump) <= _cost(b, trump) ? a : b);
  }

  static PlayingCard chooseCard({
    required List<PlayingCard> legal,
    required Trick trick,
    required Suit trump,
    required int player,
    required int bidderTeam,
    BotDifficulty difficulty = BotDifficulty.normal,
    List<PlayingCard> playedCards = const [],
  }) {
    if (legal.length == 1) return legal.first;
    if (trick.plays.isEmpty) {
      return _chooseLead(
        legal,
        trump,
        player,
        bidderTeam,
        difficulty: difficulty,
        playedCards: playedCards,
      );
    }

    final currentWinner = Rules.trickWinner(trick, trump);
    final partnerWinning = Rules.teamOf(currentWinner) == Rules.teamOf(player);
    if (partnerWinning) {
      if (difficulty == BotDifficulty.pro && trick.plays.length < 3) {
        final winningCard =
            trick.plays.firstWhere((p) => p.player == currentWinner).card;
        // إذا كان الشريك متقدماً بورقة ضعيفة وهناك خصم سيلعب بعدنا، نحاول تأمين الأكلة بورقة متوسطة
        if (!winningCard.isJoker &&
            winningCard.suit != trump &&
            winningCard.rank!.value < Rank.queen.value) {
          final safeBoost = legal
              .where((c) => !c.isJoker && c.suit != trump && c.rank!.value >= Rank.king.value)
              .toList();
          if (safeBoost.isNotEmpty) return _cheapest(safeBoost, trump);
        }
      }
      return _cheapest(legal, trump);
    }

    final winners = legal.where((c) {
      final next = trick.add(PlayedCard(player: player, card: c));
      return Rules.trickWinner(next, trump) == player;
    }).toList();
    if (winners.isNotEmpty) {
      if (difficulty == BotDifficulty.pro) {
        final nonJokerWinners = winners.where((c) => !c.isJoker).toList();
        if (nonJokerWinners.isNotEmpty) {
          return _cheapest(nonJokerWinners, trump);
        }
      }
      return _cheapest(winners, trump);
    }
    return _cheapest(legal, trump);
  }

  static PlayingCard _chooseLead(
    List<PlayingCard> legal,
    Suit trump,
    int player,
    int bidderTeam, {
    BotDifficulty difficulty = BotDifficulty.normal,
    List<PlayingCard> playedCards = const [],
  }) {
    final nonTrump = legal.where((c) => c.suit != trump).toList();
    if (difficulty == BotDifficulty.pro) {
      // في المستوى المحترف: نلعب الآصات أو الملوك الرابحة أولاً ونحتفظ بالجيكر لوقت الحسم
      final aces = nonTrump.where((c) => c.rank == Rank.ace).toList();
      if (aces.isNotEmpty) return aces.first;

      final bossKings = nonTrump.where((c) {
        if (c.rank != Rank.king) return false;
        return playedCards.any((p) => p.suit == c.suit && p.rank == Rank.ace);
      }).toList();
      if (bossKings.isNotEmpty) return bossKings.first;

      if (Rules.teamOf(player) == bidderTeam) {
        final topTrumps = legal
            .where((c) => c.suit == trump && c.rank!.value >= Rank.king.value)
            .toList();
        if (topTrumps.isNotEmpty) {
          topTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
          return topTrumps.first;
        }
      }
    }

    final jokers = legal.where((c) => c.isJoker).toList();
    if (jokers.isNotEmpty) {
      return jokers.firstWhere((c) => c.isRedJoker, orElse: () => jokers.first);
    }
    final aces = nonTrump.where((c) => c.rank == Rank.ace).toList();
    if (aces.isNotEmpty) return aces.first;

    if (Rules.teamOf(player) == bidderTeam) {
      final topTrumps = legal
          .where((c) => c.suit == trump && c.rank!.value >= Rank.king.value)
          .toList();
      if (topTrumps.isNotEmpty) {
        topTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
        return topTrumps.first;
      }
    }
    final pool = nonTrump.isNotEmpty ? nonTrump : legal;
    return _cheapest(pool, trump);
  }
}
