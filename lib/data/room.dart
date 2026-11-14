import 'dart:convert';

import 'package:equatable/equatable.dart';

class RoomSeat extends Equatable {
  const RoomSeat({this.userId, required this.name, required this.isBot});

  final String? userId;
  final String name;
  final bool isBot;

  factory RoomSeat.fromJson(Map<String, dynamic> j) => RoomSeat(
        userId: j['id'] as String?,
        name: (j['name'] as String?) ?? 'لاعب',
        isBot: (j['bot'] as bool?) ?? false,
      );

  @override
  List<Object?> get props => [userId, name, isBot];
}

class Room extends Equatable {
  const Room({
    required this.code,
    required this.hostId,
    required this.status,
    required this.targetScore,
    required this.turnSeconds,
    required this.seats,
  });

  final String code;
  final String hostId;

  /// waiting | playing | finished
  final String status;
  final int targetScore;
  final int turnSeconds;

  /// 4 مقاعد، null = فاضي.
  final List<RoomSeat?> seats;

  factory Room.fromJson(Map<String, dynamic> j) {
    dynamic raw = j['seats'];
    if (raw is String) raw = jsonDecode(raw);
    final list = (raw as List).map((e) {
      if (e == null) return null;
      return RoomSeat.fromJson(Map<String, dynamic>.from(e as Map));
    }).toList();
    while (list.length < 4) {
      list.add(null);
    }
    return Room(
      code: j['code'] as String,
      hostId: j['host_id'] as String,
      status: j['status'] as String,
      targetScore: j['target_score'] as int,
      turnSeconds: j['turn_seconds'] as int,
      seats: list,
    );
  }

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';

  int? seatOf(String userId) {
    for (var i = 0; i < seats.length; i++) {
      if (seats[i]?.userId == userId) return i;
    }
    return null;
  }

  /// مقاعد اللاعبين الحقيقيين.
  Set<int> get humanSeats => {
        for (var i = 0; i < seats.length; i++)
          if (seats[i] != null && !seats[i]!.isBot) i,
      };

  List<String> get names => [
        for (var i = 0; i < 4; i++) seats[i]?.name ?? 'بوت $i',
      ];

  @override
  List<Object?> get props =>
      [code, hostId, status, targetScore, turnSeconds, seats];
}
