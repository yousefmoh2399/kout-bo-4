part of 'game_bloc.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => const [];
}

/// بدء لعبة جديدة (تصفير النقاط).
class GameStarted extends GameEvent {
  const GameStarted({this.seat});
  final int? seat;

  @override
  List<Object?> get props => [seat];
}

/// مزايدة: 5..9، أو 0 للتمرير ("طاف"). [seat] = null يعني اللاعب المحلي.
class BidPlaced extends GameEvent {
  const BidPlaced(this.bid, {this.seat});
  final int bid;
  final int? seat;

  @override
  List<Object?> get props => [bid, seat];
}

class TrumpChosen extends GameEvent {
  const TrumpChosen(this.suit, {this.seat});
  final Suit suit;
  final int? seat;

  @override
  List<Object?> get props => [suit, seat];
}

class CardPlayed extends GameEvent {
  const CardPlayed(this.card, {this.seat});
  final PlayingCard card;
  final int? seat;

  @override
  List<Object?> get props => [card, seat];
}

class NextRoundRequested extends GameEvent {
  const NextRoundRequested({this.seat});
  final int? seat;

  @override
  List<Object?> get props => [seat];
}

/// انتهت مهلة دور لاعب (داخلي - يطلقه المؤقت).
class TurnTimedOut extends GameEvent {
  const TurnTimedOut({required this.seat, required this.deadline});
  final int seat;
  final DateTime deadline;

  @override
  List<Object?> get props => [seat, deadline];
}

/// لاعب بعيد (غير المضيف) استقبل حالة جديدة من المضيف.
class StateReceived extends GameEvent {
  const StateReceived(this.state);
  final GameState state;

  @override
  List<Object?> get props => [state];
}

/// لاعب بشري غادر اللعبة: يلعب البوت مكانه حتى نهايتها.
class SeatLeft extends GameEvent {
  const SeatLeft(this.seat);
  final int seat;

  @override
  List<Object?> get props => [seat];
}

/// تفعيل أو إيقاف اللعب التلقائي (البوت يلعب عن اللاعب).
class AutoPlayToggled extends GameEvent {
  const AutoPlayToggled({required this.enabled, this.seat});
  final bool enabled;
  final int? seat;

  @override
  List<Object?> get props => [enabled, seat];
}

/// انتهاء الوقت المحدد للمباراة.
class MatchTimedOut extends GameEvent {
  const MatchTimedOut();
}

/// استلام استضافة الغرفة بعد خروج المضيف السابق.
class HostMigrated extends GameEvent {
  const HostMigrated({required this.fullState, required this.oldHostSeat});
  final GameState fullState;
  final int oldHostSeat;

  @override
  List<Object?> get props => [fullState, oldHostSeat];
}
