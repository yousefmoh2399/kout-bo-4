import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/lobby_cubit.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/online_game_session.dart';
import '../data/room.dart';
import '../data/room_repository.dart';
import 'effects.dart';
import 'game_page.dart';
import 'widgets.dart';

/// غرفة الانتظار: ينشئها المضيف أو ينضم لها اللاعب بكود.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key, this.create, this.joinCode})
      : assert(create != null || joinCode != null);

  final GameSettings? create;
  final String? joinCode;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final LobbyCubit _cubit;
  late final RoomRepository _repo;
  late final String _userId;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    _userId = auth.userId!;
    _repo = RoomRepository(Supabase.instance.client);
    _cubit = LobbyCubit(_repo, userId: _userId, userName: auth.name);
    if (widget.create != null) {
      _cubit.create(widget.create!);
    } else {
      _cubit.join(widget.joinCode!);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _launch(Room room) async {
    _launched = true;
    final client = Supabase.instance.client;
    final session = OnlineGameSession(client: client, room: room, userId: _userId);
    await session.start();
    if (!mounted) {
      await session.dispose();
      return;
    }
    final code = room.code;
    final isHost = session.isHost;
    final repo = _repo;
    await Navigator.pushReplacement(
      context,
      appRoute<void>(
        GamePage(
          bloc: session.bloc,
          roomCode: code,
          emotes: session.emotes,
          onEmote: session.sendEmote,
          hostLost: session.hostLost,
          onClose: () {
            session.dispose();
            if (isHost) repo.finishRoom(code);
            repo.leaveRoom(code);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<LobbyCubit, LobbyState>(
        listener: (context, s) {
          if (s.closed) {
            showSnack(context, 'أغلق المضيف الغرفة');
            Navigator.pop(context);
            return;
          }
          final room = s.room;
          if (room != null &&
              room.isPlaying &&
              !_launched &&
              room.seatOf(_userId) != null) {
            _launch(room);
          }
        },
        builder: (context, s) {
          return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop && !_launched) _cubit.leave();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('غرفة اللعب'),
              ),
              extendBodyBehindAppBar: true,
              body: FeltBackground(
                child: SafeArea(child: _body(context, s)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, LobbyState s) {
    final room = s.room;
    if (room == null) {
      if (s.busy) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.error ?? 'تعذر فتح الغرفة', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              GoldButton(label: 'رجوع', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );
    }

    final isHost = room.hostId == _userId;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                child: Column(
                  children: [
                    const Text('كود الدعوة', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        showSnack(context, 'تم نسخ الكود');
                      },
                      child: Text(
                        room.code,
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الهدف ${room.targetScore} نقطة • ${room.turnSeconds == 0 ? 'بدون مؤقت' : '${room.turnSeconds} ثانية للدور'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    GoldButton(
                      label: 'شارك الدعوة',
                      icon: Icons.share_rounded,
                      outlined: true,
                      onPressed: () => Share.share(
                        'تعال العب معي كوت بو! ادخل التطبيق واختر "انضم بكود" واكتب: ${room.code}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  for (final seat in const [0, 1, 2, 3])
                    _SeatTile(
                      seat: seat,
                      info: room.seats[seat],
                      isMe: room.seats[seat]?.userId == _userId,
                      canEdit: isHost && seat != 0,
                      onToggleBot: (bot) => _cubit.setBot(seat, bot),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'اللاعبان المتقابلان فريق واحد. المقاعد الفاضية تمتلئ بالبوتات عند البدء.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: 16),
              if (isHost)
                GoldButton(
                  label: 'ابدأ اللعبة',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _cubit.start,
                )
              else
                const Center(
                  child: Text('بانتظار المضيف ليبدأ اللعبة...',
                      style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.info,
    required this.isMe,
    required this.canEdit,
    required this.onToggleBot,
  });

  final int seat;
  final RoomSeat? info;
  final bool isMe;
  final bool canEdit;
  final ValueChanged<bool> onToggleBot;

  @override
  Widget build(BuildContext context) {
    final team = seat % 2;
    final color = team == 0 ? const Color(0xFF2E7D6B) : const Color(0xFF8D5A2B);
    final seatInfo = info;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(110),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMe ? AppColors.gold : Colors.white24, width: isMe ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('الفريق ${team + 1}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 6),
          if (seatInfo == null) ...[
            const Icon(Icons.person_add_alt_1_rounded, color: Colors.white38),
            const Text('فاضي', style: TextStyle(color: Colors.white54)),
          ] else ...[
            Icon(seatInfo.isBot ? Icons.smart_toy_rounded : Icons.person_rounded, color: Colors.white),
            Text(
              seatInfo.isBot ? seatInfo.name : (isMe ? '${seatInfo.name} (أنت)' : seatInfo.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          if (canEdit && (seatInfo == null || seatInfo.isBot))
            TextButton(
              onPressed: () => onToggleBot(seatInfo == null),
              child: Text(seatInfo == null ? '+ أضف بوت' : 'إزالة البوت'),
            ),
        ],
      ),
    );
  }
}
