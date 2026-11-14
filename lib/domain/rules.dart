import 'package:equatable/equatable.dart';

import 'card.dart';

class PlayedCard extends Equatable {
  const PlayedCard({required this.player, required this.card});
  final int player;
  final PlayingCard card;

  @override
  List<Object?> get props => [player, card];
}

/// اللمة الحالية. [forcedJokerLead] = بدأ اللاعب بالجيكر/الميكر بشكل غير قانوني
/// لأنها كانت ورقته الأخيرة.
class Trick extends Equatable {
  const Trick({this.plays = const [], this.forcedJokerLead = false});

  final List<PlayedCard> plays;
  final bool forcedJokerLead;

  bool get isEmpty => plays.isEmpty;
  bool get isComplete => plays.length == 4;

  Trick add(PlayedCard play, {bool forcedLead = false}) {
    return Trick(
      plays: [...plays, play],
      forcedJokerLead: plays.isEmpty ? forcedLead : forcedJokerLead,
    );
  }

  @override
  List<Object?> get props => [plays, forcedJokerLead];
}

/// قوانين اللعبة (دوال نقية بدون حالة) - اللاعبون 0..3 بعكس عقارب الساعة،
/// الفريق = رقم اللاعب % 2.
class Rules {
  Rules._();

  static const int handSize = 9;
  static const int minBid = 5;
  static const int maxBid = 9;

  static int teamOf(int player) => player % 2;

  /// نوع اللمة (النوع الذي يجب اتباعه). null = لم يتحدد بعد.
  static Suit? leadSuit(Trick trick, Suit trump) {
    if (trick.plays.isEmpty) return null;
    final first = trick.plays.first.card;
    if (!first.isJoker) return first.suit;
    // بدء قانوني بالجيكر/الميكر: يجب على الآخرين لعب الحكم.
    if (!trick.forcedJokerLead) return trump;
    // بدء غير قانوني: نوع أول ورقة عادية تُرمى بعده هو نوع اللمة.
    for (final p in trick.plays.skip(1)) {
      if (!p.card.isJoker) return p.card.suit;
    }
    return null;
  }

  /// في البدء غير القانوني، الجيكر/الميكر الذي يُرمى قبل تحديد النوع بلا مرتبة.
  static bool _isRankless(Trick trick, int index) {
    if (!trick.forcedJokerLead) return false;
    for (var i = 0; i <= index; i++) {
      if (!trick.plays[i].card.isJoker) return false;
    }
    return true;
  }

  /// الترتيب: الجيكر > A الحكم > الميكر > باقي الحكم > نوع اللمة > غير ذلك.
  static int strength(
    PlayingCard c,
    Suit trump,
    Suit? leadSuit, {
    bool rankless = false,
  }) {
    if (c.isJoker) {
      if (rankless) return -1;
      return c.isRedJoker ? 1000 : 800;
    }
    if (c.suit == trump) {
      return c.rank == Rank.ace ? 900 : 500 + c.rank!.value;
    }
    if (c.suit == leadSuit) return 100 + c.rank!.value;
    return 0;
  }

  /// رقم اللاعب الفائز (أو المتقدم حالياً إذا كانت اللمة غير مكتملة).
  static int trickWinner(Trick trick, Suit trump) {
    final lead = leadSuit(trick, trump);
    var best = -2;
    var winner = trick.plays.first.player;
    for (var i = 0; i < trick.plays.length; i++) {
      final p = trick.plays[i];
      final s = strength(p.card, trump, lead, rankless: _isRankless(trick, i));
      if (s > best) {
        best = s;
        winner = p.player;
      }
    }
    return winner;
  }

  /// هل يحق للاعب بدء اللمة بهذه الورقة؟
  /// الجيكر/الميكر: يُسمح فقط إذا خرجت J,Q,K,A من الحكم، أو فريق اللاعب
  /// هو المزايد بـ 9 (الاثنان) أو بـ 8 (الجيكر فقط).
  static bool canLeadJoker({
    required PlayingCard card,
    required Suit trump,
    required int bid,
    required bool onBidderTeam,
    required List<PlayingCard> playedCards,
  }) {
    if (!card.isJoker) return true;
    const high = [Rank.jack, Rank.queen, Rank.king, Rank.ace];
    final highTrumpsGone =
        high.every((r) => playedCards.contains(PlayingCard.suited(trump, r)));
    if (highTrumpsGone) return true;
    if (!onBidderTeam) return false;
    if (bid >= 9) return true;
    if (bid == 8) return card.isRedJoker;
    return false;
  }

  static List<PlayingCard> legalPlays({
    required List<PlayingCard> hand,
    required Trick trick,
    required Suit trump,
    required int bid,
    required int player,
    required int bidderTeam,
    required List<PlayingCard> playedCards,
  }) {
    if (trick.plays.isEmpty) {
      final allowed = hand
          .where((c) => canLeadJoker(
                card: c,
                trump: trump,
                bid: bid,
                onBidderTeam: teamOf(player) == bidderTeam,
                playedCards: playedCards,
              ))
          .toList();
      // لا يوجد في اليد إلا جوكر غير مسموح => مضطر لبدء اللمة به.
      return allowed.isEmpty ? List<PlayingCard>.of(hand) : allowed;
    }
    final lead = leadSuit(trick, trump);
    if (lead == null) return List<PlayingCard>.of(hand);
    final follow = hand.where((c) => !c.isJoker && c.suit == lead).toList();
    if (follow.isEmpty) return List<PlayingCard>.of(hand);
    // يجب اتباع النوع، لكن الجيكر/الميكر يُلعبان في أي وقت.
    return [...follow, ...hand.where((c) => c.isJoker)];
  }
}
