import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/lobby_cubit.dart';
import '../core/config.dart';
import '../core/sound.dart';
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
    final session = OnlineGameSession(
      client: client,
      room: room,
      userId: _userId,
      matchMinutes: widget.create?.matchMinutes ?? 0,
      botDifficulty: widget.create?.botDifficulty ?? BotDifficulty.normal,
    );
    await session.start();
    if (!mounted) {
      await session.dispose();
      return;
    }
    final code = room.code;
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
          onTakeOverHost: session.promoteSelfFromCrash,
          onClose: () {
            session.dispose().then((_) {
              if (session.isHost && !session.migratedOut) {
                repo.finishRoom(code);
              }
              repo.leaveRoom(code);
            });
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

    final roomInfoCard = GlassCard(
      child: Column(
        children: [
          const Text('كود دعوة الأصدقاء', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              SoundService.instance.play(Sfx.click);
              SoundService.instance.tap();
              Clipboard.setData(ClipboardData(text: room.code));
              showSnack(context, 'تم نسخ كود الغرفة');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withAlpha(140), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: AppColors.goldLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded, color: AppColors.gold, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الهدف ${room.targetScore} نقطة • ${room.turnSeconds == 0 ? 'بدون مؤقت' : '${room.turnSeconds} ثانية للدور'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GoldButton(
            label: 'شارك كود الدعوة',
            icon: Icons.share_rounded,
            outlined: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onPressed: () {
              SoundService.instance.play(Sfx.click);
              Share.share(
                'تعال العب معي كوت بو ٤! ادخل التطبيق واختر "انضم بكود" واكتب: ${room.code}',
              );
            },
          ),
        ],
      ),
    );

    final seatsGrid = GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
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
    );

    final actionArea = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
          ),
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 580;

        if (isWide) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          roomInfoCard,
                          const SizedBox(height: 12),
                          actionArea,
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          seatsGrid,
                          const SizedBox(height: 8),
                          const Text(
                            'المقاعد المتقابلة فريق واحد. المقاعد الشاغرة تمتلئ ببوتات ذكية.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  roomInfoCard,
                  const SizedBox(height: 16),
                  seatsGrid,
                  const SizedBox(height: 6),
                  const Text(
                    'اللاعبان المتقابلان فريق واحد. المقاعد الفاضية تمتلئ بالبوتات عند البدء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  actionArea,
                ],
              ),
            ),
          ),
        );
      },
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
    final isTeam1 = team == 0;
    final seatInfo = info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTeam1
              ? [const Color(0x991E7453), const Color(0x990F4430)]
              : [const Color(0x997C421A), const Color(0x9948240D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? AppColors.gold : (seatInfo != null ? Colors.white30 : Colors.white12),
          width: isMe ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isMe)
            BoxShadow(color: AppColors.gold.withAlpha(70), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTeam1 ? const Color(0xFF48BB78) : const Color(0xFFED8936),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'الفريق ${team + 1}',
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (seatInfo == null) ...[
            const Icon(Icons.person_add_alt_1_rounded, color: Colors.white30, size: 22),
            const SizedBox(height: 2),
            const Text('مقعد شاغر', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ] else ...[
            Icon(
              seatInfo.isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: isMe ? AppColors.goldLight : Colors.white,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              seatInfo.isBot ? seatInfo.name : (isMe ? '${seatInfo.name} (أنت)' : seatInfo.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMe ? AppColors.goldLight : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
          if (canEdit && (seatInfo == null || seatInfo.isBot))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                onTap: () {
                  SoundService.instance.play(Sfx.click);
                  onToggleBot(seatInfo == null);
                },
                child: Text(
                  seatInfo == null ? '+ أضف بوت' : 'إزالة البوت',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: seatInfo == null ? AppColors.gold : Colors.white60,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
