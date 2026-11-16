import 'package:equatable/equatable.dart';

enum Suit {
  spades('♠', false),
  hearts('♥', true),
  diamonds('♦', true),
  clubs('♣', false);

  const Suit(this.symbol, this.isRed);
  final String symbol;
  final bool isRed;

  /// اسم الرمز الكويتي الأصيل في الجنجفة (سبيت، هاص، ديمن، كلفس)
  String get nameAr {
    switch (this) {
      case Suit.spades:
        return 'سبيت';
      case Suit.hearts:
        return 'هاص';
      case Suit.diamonds:
        return 'ديمن';
      case Suit.clubs:
        return 'كلفس';
    }
  }

  /// الاسم المعرّف للرمز في الجنجفة (السبيت، الهاص، الديمن، الكلفس)
  String get nameArDef {
    switch (this) {
      case Suit.spades:
        return 'السبيت';
      case Suit.hearts:
        return 'الهاص';
      case Suit.diamonds:
        return 'الديمن';
      case Suit.clubs:
        return 'الكلفس';
    }
  }
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

  /// اسم الرتبة في الجنجفة (شايب، بنت، ولد، آس...)
  String get nameAr {
    switch (this) {
      case Rank.six:
        return 'ستة';
      case Rank.seven:
        return 'سبعة';
      case Rank.eight:
        return 'ثمانية';
      case Rank.nine:
        return 'تسعة';
      case Rank.ten:
        return 'عشرة';
      case Rank.jack:
        return 'ولد';
      case Rank.queen:
        return 'بنت';
      case Rank.king:
        return 'شايب';
      case Rank.ace:
        return 'آس';
    }
  }
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

  /// الاسم الكويتي الشعبي المعتمد للكرت في لعبة الكوت
  String get nameAr {
    if (isJoker) {
      return isRedJoker ? 'الجوكر الأحمر (البكر)' : 'الجوكر الأسود (العوير)';
    }
    if (rank == Rank.king) {
      return 'شايب ${suit!.nameArDef}';
    }
    if (rank == Rank.queen) {
      return 'بنت ${suit!.nameArDef}';
    }
    if (rank == Rank.jack) {
      return 'ولد ${suit!.nameArDef}';
    }
    if (rank == Rank.ace) {
      return 'آس ${suit!.nameArDef}';
    }
    return '${rank!.nameAr} ${suit!.nameArDef}';
  }

  /// مسار الصورة الاحترافية للكرت في مجلد الأصول
  String get assetPath {
    if (isJoker) {
      return isRedJoker
          ? 'assets/cards/joker_red.png'
          : 'assets/cards/joker_black.png';
    }
    return 'assets/cards/${suit!.name}_${rank!.label}.png';
  }

  @override
  List<Object?> get props => [suit, rank, joker];

  @override
  String toString() => isJoker ? 'Joker(${joker!.name})' : '${rank!.label}${suit!.symbol}';
}
