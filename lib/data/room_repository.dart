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
    final u = _client.auth.currentUser;
    if (u == null || u.isAnonymous) {
      throw Exception('عفواً، إنشاء الغرف متاح فقط للأعضاء المسجلين.');
    }
    try {
      final code = await _client.rpc('create_room_with_stake', params: {
        'p_name': name,
        'p_target': settings.targetScore,
        'p_turn': settings.turnSeconds,
        'p_stake': settings.stakePoints,
      });
      return code as String;
    } catch (e) {
      // إذا كانت الغرفة بدون نقاط وفشلت دالة النقاط، نجرب الدالة الكلاسيكية كاحتياط
      if (settings.stakePoints == 0) {
        try {
          final code = await _client.rpc('create_room', params: {
            'p_name': name,
            'p_target': settings.targetScore,
            'p_turn': settings.turnSeconds,
          });
          return code as String;
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Room> joinRoom({required String code, required String name}) async {
    final u = _client.auth.currentUser;
    if (u == null || u.isAnonymous) {
      throw Exception('عفواً، الانضمام للغرف متاح فقط للأعضاء المسجلين.');
    }
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
    final json = await _client.rpc('join_room_with_stake', params: {
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

  Future<void> switchSeat(String code, int targetSeat) =>
      _client.rpc('switch_seat', params: {
        'p_code': code.trim().toUpperCase(),
        'p_target_seat': targetSeat,
      });

  Future<void> startRoom(String code) =>
      _client.rpc('start_room', params: {'p_code': code});

  Future<void> finishRoom(String code) =>
      _client.rpc('finish_room', params: {'p_code': code});

  /// تم إيقاف توزيع جوائز الفوز بالنقاط التزاماً باللعب النظيف ومنع المراهنات
  Future<void> awardRoomWinnings({
    required String code,
    required int winningTeam,
  }) async {
    // اللعب نظيف وبدون أي رهانات أو أرباح نقاط عند الفوز
  }

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
