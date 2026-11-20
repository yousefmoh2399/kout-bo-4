import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../core/config.dart';
import '../data/room.dart';
import '../data/room_repository.dart';

class LobbyState extends Equatable {
  const LobbyState({
    this.busy = true,
    this.room,
    this.error,
    this.closed = false,
  });

  final bool busy;
  final Room? room;
  final String? error;

  /// الغرفة أُغلقت (غادر المضيف).
  final bool closed;

  @override
  List<Object?> get props => [busy, room, error, closed];
}

class LobbyCubit extends Cubit<LobbyState> {
  LobbyCubit(this._repo, {required this.userId, required this.userName})
      : super(const LobbyState());

  final RoomRepository _repo;
  final String userId;
  final String userName;
  StreamSubscription<Room?>? _sub;

  bool get isHost => state.room?.hostId == userId;

  Future<void> create(GameSettings settings) async {
    try {
      final code = await _repo.createRoom(name: userName, settings: settings);
      _listen(code);
    } catch (e) {
      // ignore: avoid_print
      print('Lobby create error: $e');
      emit(LobbyState(busy: false, error: _message(e)));
    }
  }

  Future<void> join(String code) async {
    try {
      final room = await _repo.joinRoom(code: code, name: userName);
      emit(LobbyState(busy: false, room: room));
      _listen(room.code);
    } catch (e) {
      // ignore: avoid_print
      print('Lobby join error: $e');
      emit(LobbyState(busy: false, error: _message(e)));
    }
  }

  void _listen(String code) {
    _sub?.cancel();
    _sub = _repo.watch(code).listen((room) {
      if (room == null) {
        emit(const LobbyState(busy: false, closed: true));
      } else {
        emit(LobbyState(busy: false, room: room));
      }
    });
  }

  Future<void> setBot(int seat, bool bot) async {
    final code = state.room?.code;
    if (code == null) return;
    try {
      await _repo.setSeatBot(code, seat, bot);
    } catch (_) {}
  }

  Future<void> switchSeat(int targetSeat) async {
    final code = state.room?.code;
    if (code == null) return;
    try {
      await _repo.switchSeat(code, targetSeat);
    } catch (e) {
      // ignore: avoid_print
      print('Lobby switchSeat error: $e');
      emit(LobbyState(busy: false, room: state.room, error: _message(e)));
    }
  }

  Future<void> start() async {
    final code = state.room?.code;
    if (code == null) return;
    try {
      await _repo.startRoom(code);
    } catch (e) {
      emit(LobbyState(busy: false, room: state.room, error: _message(e)));
    }
  }

  Future<void> leave() async {
    final code = state.room?.code;
    await _sub?.cancel();
    _sub = null;
    if (code != null) {
      try {
        await _repo.leaveRoom(code);
      } catch (_) {}
    }
  }

  String _message(Object e) {
    final text = e is PostgrestException
        ? (e.message.isNotEmpty ? e.message : (e.details?.toString() ?? e.toString()))
        : e.toString();
    if (text.contains('guest_not_allowed')) {
      return 'سجّل الدخول أولاً للتمكن من اللعب في هذه الغرفة.';
    }
    if (text.contains('insufficient_coins')) {
      return 'رصيدك من النقاط لا يكفي لدخول هذه الغرفة. اشحن رصيدك من المتجر!';
    }
    if (text.contains('room_not_found')) return 'الغرفة غير موجودة';
    if (text.contains('room_full')) return 'الغرفة ممتلئة';
    if (text.contains('seat_occupied')) return 'هذا المقعد مشغول بالفعل من قِبل لاعب آخر';
    if (text.contains('not_in_room')) return 'أنت لست منضماً لهذه الغرفة';
    if (text.contains('room_started') || text.contains('room_not_waiting')) {
      return 'اللعبة بدأت بالفعل';
    }
    if (text.contains('not_authenticated')) return 'سجّل الدخول أولاً';
    if (text.contains('bad_settings')) return 'إعدادات الغرفة غير صالحة';
    if (text.contains('bad_stake')) return 'رسوم الغرفة المحددة غير صالحة';
    if (text.contains('coin_transactions_room_code_fkey') || text.contains('23503')) {
      return 'يجب تحديث سكيما قاعدة البيانات في Supabase لإصلاح قيد الغرف';
    }
    return 'حدث خطأ: $text';
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
