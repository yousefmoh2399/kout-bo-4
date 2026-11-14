import 'package:equatable/equatable.dart';

enum Suit {
  spades('♠', false),
  hearts('♥', true),
  diamonds('♦', true),
  clubs('♣', false);

  const Suit(this.symbol, this.isRed);
  final String symbol;
  final bool isRed;
}

enum Rank {
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.label);
  final int value;
  final String label;
}

enum JokerKind { red, black }

class PlayingCard extends Equatable {
  const PlayingCard.suited(this.suit, this.rank) : joker = null;
  const PlayingCard.joker(this.joker)
      : suit = null,
        rank = null;

  final Suit? suit;
  final Rank? rank;
  final JokerKind? joker;

  bool get isJoker => joker != null;
  bool get isRedJoker => joker == JokerKind.red;

  @override
  List<Object?> get props => [suit, rank, joker];

  @override
  String toString() => isJoker ? 'Joker(${joker!.name})' : '${rank!.label}${suit!.symbol}';
}
