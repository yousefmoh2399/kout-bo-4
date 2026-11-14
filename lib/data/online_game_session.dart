import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/game_bloc.dart';
import '../bloc/game_codec.dart';
import '../core/config.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
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
    int matchMinutes = 0,
    BotDifficulty botDifficulty = BotDifficulty.normal,
  })  : mySeat = room.seatOf(userId)!,
        isHost = room.hostId == userId {
    bloc = GameBloc(
      localSeat: mySeat,
      humanSeats: room.humanSeats,
      remote: !isHost,
      turnSeconds: room.turnSeconds,
      matchMinutes: matchMinutes,
      targetScore: room.targetScore,
      botDifficulty: botDifficulty,
      names: room.names,
    );
  }

  static const Duration _hostTimeout = Duration(seconds: 15);

  final SupabaseClient client;
  final Room room;
  final String userId;
  final int mySeat;
  bool isHost;
  bool migratedOut = false;
  late final GameBloc bloc;

  /// يصبح true إذا انقطع المضيف (لا حالة جديدة منه).
  final ValueNotifier<bool> hostLost = ValueNotifier<bool>(false);

  final StreamController<Emote> _emotes = StreamController<Emote>.broadcast();
  Stream<Emote> get emotes => _emotes.stream;

  RealtimeChannel? _channel;
  Timer? _heartbeat;
  Timer? _watchdog;
  DateTime _lastStateAt = DateTime.now();
  final Set<int> _leftHumanSeats = {};
  void Function()? _bindHostListeners;
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
        if (seat is int && text is String) {
          if (kQuickPhrases.contains(text) || payload['system'] == true) {
            _emotes.add(Emote(seat: seat, text: text));
          }
        }
      },
    );

    void bindHostListeners() {
      bloc.publishState = _publish;
      channel
          .onBroadcast(
            event: 'action',
            callback: (payload) {
              try {
                final e = GameCodec.actionFromJson(
                  Map<String, dynamic>.from(payload),
                );
                if (e is SeatLeft) {
                  _leftHumanSeats.add(e.seat);
                  final notice = 'غادر ${room.names[e.seat]} — البوت يكمل';
                  _emotes.add(Emote(seat: e.seat, text: notice));
                  channel.sendBroadcastMessage(
                    event: 'emote',
                    payload: {'seat': e.seat, 'text': notice, 'system': true},
                  );
                }
                if (e != null && !bloc.isClosed) bloc.add(e);
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'sync',
            callback: (_) => _publish(bloc.state),
          );
    }

    _bindHostListeners = bindHostListeners;

    if (isHost) {
      bindHostListeners();
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
          if (bloc.isClosed || isHost) return;
          try {
            final s = GameCodec.decode(Map<String, dynamic>.from(payload));
            _lastStateAt = DateTime.now();
            if (hostLost.value) hostLost.value = false;
            bloc.add(StateReceived(s));
          } catch (_) {}
        },
      );
      channel.onBroadcast(
        event: 'host_handoff',
        callback: (payload) {
          if (bloc.isClosed || _disposed) return;
          try {
            final newHostSeat = payload['newHostSeat'] as int;
            final oldHostSeat = payload['oldHostSeat'] as int;
            final leaverName = (payload['leaverName'] as String?) ?? room.names[oldHostSeat];
            _leftHumanSeats.add(oldHostSeat);
            _lastStateAt = DateTime.now();
            if (hostLost.value) hostLost.value = false;
            _emotes.add(Emote(seat: oldHostSeat, text: 'غادر $leaverName — البوت يكمل'));

            if (newHostSeat == mySeat) {
              isHost = true;
              _watchdog?.cancel();
              bindHostListeners();
              _heartbeat?.cancel();
              _heartbeat = Timer.periodic(
                const Duration(seconds: 4),
                (_) => _publish(bloc.state),
              );
              final fullState = GameCodec.decode(
                Map<String, dynamic>.from(payload['state'] as Map),
              );
              bloc.add(HostMigrated(fullState: fullState, oldHostSeat: oldHostSeat));
            }
          } catch (_) {}
        },
      );
      _lastStateAt = DateTime.now();
      _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
        final over = bloc.state.phase == GamePhase.gameOver;
        if (!isHost && !over && DateTime.now().difference(_lastStateAt) > _hostTimeout) {
          final oldHostSeat = room.seatOf(room.hostId) ?? 0;
          final candidates = room.humanSeats
              .where((s) => s != oldHostSeat && !_leftHumanSeats.contains(s))
              .toList()
            ..sort();
          if (candidates.isNotEmpty && candidates.first == mySeat) {
            promoteSelfFromCrash();
          } else {
            hostLost.value = true;
          }
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

  /// ترقية هذا اللاعب إلى مضيف عند انقطاع المضيف السابق فجأة.
  void promoteSelfFromCrash() {
    if (isHost || _disposed || bloc.isClosed) return;
    final s = bloc.state;
    final known = <PlayingCard>{
      ...s.playedCards,
      ...s.trick.plays.map((p) => p.card),
      ...s.hands[mySeat],
    };
    final pool = Deck.build().where((c) => !known.contains(c)).toList()
      ..shuffle(Random());
    var cursor = 0;
    final hands = <List<PlayingCard>>[];
    for (var seat = 0; seat < 4; seat++) {
      if (seat == mySeat) {
        hands.add(s.hands[mySeat]);
      } else {
        final count = s.hands[seat].length;
        final end = (cursor + count).clamp(0, pool.length);
        hands.add(Deck.sortHand(pool.sublist(cursor, end)));
        cursor = end;
      }
    }

    final oldHostSeat = room.seatOf(room.hostId) ?? 0;
    isHost = true;
    hostLost.value = false;
    _watchdog?.cancel();
    _leftHumanSeats.add(oldHostSeat);
    _bindHostListeners?.call();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _publish(bloc.state),
    );
    final notice = 'انقطع ${room.names[oldHostSeat]} — تم نقل الاستضافة واللعب مستمر';
    _emotes.add(Emote(seat: oldHostSeat, text: notice));
    _channel?.sendBroadcastMessage(
      event: 'emote',
      payload: {'seat': oldHostSeat, 'text': notice, 'system': true},
    );
    bloc.add(HostMigrated(
      fullState: s.copyWith(hands: hands),
      oldHostSeat: oldHostSeat,
    ));
  }

  /// طلب مزامنة فورية للحالة الحالية عند شعور اللاعب بتأخر الشبكة.
  void requestResync() {
    if (_disposed) return;
    if (isHost) {
      _publish(bloc.state);
    } else {
      hostLost.value = false;
      _lastStateAt = DateTime.now();
      _channel?.sendBroadcastMessage(
        event: 'sync',
        payload: {'seat': mySeat},
      );
    }
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
      if (isHost) {
        // عند خروج المضيف: ننقل الاستضافة لأقرب لاعب بشري ليُكمل الباقون بدون توقف.
        final candidates = room.humanSeats
            .where((s) => s != mySeat && !_leftHumanSeats.contains(s))
            .toList()
          ..sort();
        if (candidates.isNotEmpty &&
            !bloc.isClosed &&
            bloc.state.phase != GamePhase.gameOver) {
          migratedOut = true;
          final newHost = candidates.first;
          try {
            await c.sendBroadcastMessage(
              event: 'host_handoff',
              payload: {
                'newHostSeat': newHost,
                'oldHostSeat': mySeat,
                'leaverName': room.names[mySeat],
                'state': GameCodec.encodeFull(bloc.state, forSeat: newHost),
              },
            );
          } catch (_) {}
        }
      } else {
        // أخبر المضيف والجميع بأن البوت سيكمل مكاني.
        try {
          await c.sendBroadcastMessage(
            event: 'action',
            payload: GameCodec.actionToJson(SeatLeft(mySeat), mySeat),
          );
          await c.sendBroadcastMessage(
            event: 'emote',
            payload: {
              'seat': mySeat,
              'text': 'غادر ${room.names[mySeat]} — البوت يكمل',
              'system': true,
            },
          );
        } catch (_) {}
      }
      await client.removeChannel(c);
    }
    await _emotes.close();
  }
}
