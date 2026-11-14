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
      emit(LobbyState(busy: false, error: _message(e)));
    }
  }

  Future<void> join(String code) async {
    try {
      final room = await _repo.joinRoom(code: code, name: userName);
      emit(LobbyState(busy: false, room: room));
      _listen(room.code);
    } catch (e) {
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
    final text = e is PostgrestException ? e.message : e.toString();
    if (text.contains('room_not_found')) return 'الغرفة غير موجودة';
    if (text.contains('room_full')) return 'الغرفة ممتلئة';
    if (text.contains('room_started')) return 'اللعبة بدأت بالفعل';
    if (text.contains('not_authenticated')) return 'سجّل الدخول أولاً';
    return 'حدث خطأ، حاول مرة أخرى';
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
