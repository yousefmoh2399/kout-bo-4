import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import 'room.dart';

class RoomRepository {
  RoomRepository(this._client);

  final SupabaseClient _client;

  Future<String> createRoom({
    required String name,
    required GameSettings settings,
  }) async {
    final code = await _client.rpc('create_room', params: {
      'p_name': name,
      'p_target': settings.targetScore,
      'p_turn': settings.turnSeconds,
    });
    return code as String;
  }

  Future<Room> joinRoom({required String code, required String name}) async {
    final cleanCode = code.trim().toUpperCase();
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      try {
        final existing = await _client
            .from('rooms')
            .select()
            .eq('code', cleanCode)
            .maybeSingle();
        if (existing != null) {
          final room = Room.fromJson(Map<String, dynamic>.from(existing));
          if (room.seatOf(uid) != null) return room;
        }
      } catch (_) {}
    }
    final json = await _client.rpc('join_room', params: {
      'p_code': cleanCode,
      'p_name': name,
    });
    return Room.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// يبحث عن أي غرفة نشطة (منتظرة أو جارية) يشغلها اللاعب حالياً للعودة إليها.
  Future<Room?> findMyActiveRoom(String userId) async {
    try {
      final rows = await _client
          .from('rooms')
          .select()
          .inFilter('status', ['waiting', 'playing'])
          .order('created_at', ascending: false)
          .limit(12);
      for (final r in rows) {
        final room = Room.fromJson(Map<String, dynamic>.from(r));
        if (room.seatOf(userId) != null) return room;
      }
    } catch (_) {}
    return null;
  }

  Future<void> leaveRoom(String code) =>
      _client.rpc('leave_room', params: {'p_code': code});

  Future<void> setSeatBot(String code, int seat, bool bot) => _client.rpc(
        'set_seat_bot',
        params: {'p_code': code, 'p_seat': seat, 'p_bot': bot},
      );

  Future<void> startRoom(String code) =>
      _client.rpc('start_room', params: {'p_code': code});

  Future<void> finishRoom(String code) =>
      _client.rpc('finish_room', params: {'p_code': code});

  /// يبث تحديثات الغرفة. null = الغرفة حُذفت (غادر المضيف).
  Stream<Room?> watch(String code) {
    late final StreamController<Room?> controller;
    RealtimeChannel? channel;

    controller = StreamController<Room?>(
      onListen: () async {
        channel = _client
            .channel('room-db-$code')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rooms',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'code',
                value: code,
              ),
              callback: (payload) {
                if (payload.eventType == PostgresChangeEvent.delete) {
                  controller.add(null);
                } else {
                  controller.add(Room.fromJson(payload.newRecord));
                }
              },
            )
            .subscribe();
        final row =
            await _client.from('rooms').select().eq('code', code).maybeSingle();
        if (row != null && !controller.isClosed) {
          controller.add(Room.fromJson(row));
        }
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }
}
