import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/game_bloc.dart';
import '../bloc/game_codec.dart';
import 'emote.dart';
import 'room.dart';

/// يربط [GameBloc] بقناة Supabase Realtime.
///
/// المضيف (host) هو الحَكَم: يشغّل منطق اللعبة والبوتات، ويبث لكل لاعب
/// نسخته من الحالة (يده فقط مكشوفة) على الحدث `state_<seat>`.
/// اللاعبون الآخرون يرسلون أفعالهم على الحدث `action` ويعرضون ما يصلهم.
/// الدردشة السريعة على الحدث `emote` من الجميع للجميع.
class OnlineGameSession {
  OnlineGameSession({
    required this.client,
    required this.room,
    required this.userId,
  })  : mySeat = room.seatOf(userId)!,
        isHost = room.hostId == userId {
    bloc = GameBloc(
      localSeat: mySeat,
      humanSeats: room.humanSeats,
      remote: !isHost,
      turnSeconds: room.turnSeconds,
      targetScore: room.targetScore,
      names: room.names,
    );
  }

  static const Duration _hostTimeout = Duration(seconds: 15);

  final SupabaseClient client;
  final Room room;
  final String userId;
  final int mySeat;
  final bool isHost;
  late final GameBloc bloc;

  /// يصبح true إذا انقطع المضيف (لا حالة جديدة منه).
  final ValueNotifier<bool> hostLost = ValueNotifier<bool>(false);

  final StreamController<Emote> _emotes = StreamController<Emote>.broadcast();
  Stream<Emote> get emotes => _emotes.stream;

  RealtimeChannel? _channel;
  Timer? _heartbeat;
  Timer? _watchdog;
  DateTime _lastStateAt = DateTime.now();
  bool _disposed = false;

  Future<void> start() async {
    final channel = client.channel(
      'game-${room.code}',
      opts: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;

    channel.onBroadcast(
      event: 'emote',
      callback: (payload) {
        final seat = payload['seat'];
        final text = payload['text'];
        if (seat is int && text is String && kQuickPhrases.contains(text)) {
          _emotes.add(Emote(seat: seat, text: text));
        }
      },
    );

    if (isHost) {
      bloc.publishState = _publish;
      channel
          .onBroadcast(
            event: 'action',
            callback: (payload) {
              try {
                final e = GameCodec.actionFromJson(
                  Map<String, dynamic>.from(payload),
                );
                if (e != null && !bloc.isClosed) bloc.add(e);
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'sync',
            callback: (_) => _publish(bloc.state),
          );
    } else {
      bloc.sendAction = (event) {
        channel.sendBroadcastMessage(
          event: 'action',
          payload: GameCodec.actionToJson(event, mySeat),
        );
      };
      channel.onBroadcast(
        event: 'state_$mySeat',
        callback: (payload) {
          if (bloc.isClosed) return;
          try {
            final s = GameCodec.decode(Map<String, dynamic>.from(payload));
            _lastStateAt = DateTime.now();
            if (hostLost.value) hostLost.value = false;
            bloc.add(StateReceived(s));
          } catch (_) {}
        },
      );
      _lastStateAt = DateTime.now();
      _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
        final over = bloc.state.phase == GamePhase.gameOver;
        if (!over && DateTime.now().difference(_lastStateAt) > _hostTimeout) {
          hostLost.value = true;
        }
      });
    }

    channel.subscribe((status, error) {
      if (status != RealtimeSubscribeStatus.subscribed) return;
      if (isHost) {
        if (bloc.state.phase == GamePhase.idle) bloc.add(const GameStarted());
        // إعادة بث دورية تعالج أي رسالة ضاعت أو لاعب عاد للاتصال.
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(
          const Duration(seconds: 4),
          (_) => _publish(bloc.state),
        );
      } else {
        // عند أول اشتراك أو إعادة الاتصال: اطلب الحالة الحالية.
        channel.sendBroadcastMessage(
          event: 'sync',
          payload: {'seat': mySeat},
        );
      }
    });
  }

  void sendEmote(String text) {
    if (!kQuickPhrases.contains(text)) return;
    _emotes.add(Emote(seat: mySeat, text: text));
    _channel?.sendBroadcastMessage(
      event: 'emote',
      payload: {'seat': mySeat, 'text': text},
    );
  }

  void _publish(GameState s) {
    final channel = _channel;
    if (channel == null || _disposed || s.phase == GamePhase.idle) return;
    for (final seat in room.humanSeats) {
      if (seat == mySeat) continue;
      channel.sendBroadcastMessage(
        event: 'state_$seat',
        payload: GameCodec.encode(s, forSeat: seat),
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _heartbeat?.cancel();
    _watchdog?.cancel();
    final c = _channel;
    if (c != null) {
      if (!isHost) {
        // أخبر المضيف ليلعب البوت مكاني.
        try {
          await c.sendBroadcastMessage(
            event: 'action',
            payload: GameCodec.actionToJson(SeatLeft(mySeat), mySeat),
          );
        } catch (_) {}
      }
      await client.removeChannel(c);
    }
    await _emotes.close();
  }
}
