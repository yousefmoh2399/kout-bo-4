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
  const RoomPage({super.key, this.create, this.joinCode, this.cubit})
      : assert(create != null || joinCode != null || cubit != null);

  final GameSettings? create;
  final String? joinCode;
  final LobbyCubit? cubit;

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
    _userId = auth.userId ?? 'user-1';
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _repo = RoomRepository(Supabase.instance.client);
      _cubit = LobbyCubit(_repo, userId: _userId, userName: auth.name);
      if (auth.isGuest || auth.userId == null || auth.userId == 'local') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الدخول للغرف متاح فقط للأعضاء المسجلين.'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        });
        return;
      }
      if (widget.create != null) {
        _cubit.create(widget.create!);
      } else {
        _cubit.join(widget.joinCode!);
      }
    }
  }

  @override
  void dispose() {
    if (widget.cubit == null) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _launch(Room room) async {
    _launched = true;
    final client = Supabase.instance.client;
    final session = OnlineGameSession(
      client: client,
      room: room,
      userId: _userId,
      matchMinutes: widget.create?.matchMinutes ??
          (room.stakePoints > 0 ? (room.stakePoints ~/ 500) * 20 : 20),
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
          roomStake: room.stakePoints,
          isHost: session.isHost,
          emotes: session.emotes,
          onEmote: session.sendEmote,
          onBackground: session.notifyAppBackground,
          hostLost: session.hostLost,
          onTakeOverHost: session.promoteSelfFromCrash,
          onResync: session.requestResync,
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'الهدف ${room.targetScore} نقطة • ${room.turnSeconds == 0 ? 'بدون مؤقت' : '${room.turnSeconds} ثانية للدور'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: room.stakePoints > 0
                  ? AppColors.gold.withAlpha(35)
                  : Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: room.stakePoints > 0
                    ? AppColors.gold.withAlpha(140)
                    : Colors.white24,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    room.stakePoints > 0
                        ? Icons.monetization_on_rounded
                        : Icons.celebration_rounded,
                    size: 15,
                    color: room.stakePoints > 0 ? AppColors.goldLight : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    room.stakePoints > 0
                        ? 'رسم الديوانية: ${room.stakePoints} نقطة • لعب نظيف'
                        : 'ديوانية ودية مجانية (بدون نقاط)',
                    style: TextStyle(
                      color: room.stakePoints > 0 ? AppColors.goldLight : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GoldButton(
            label: 'شارك كود الدعوة',
            icon: Icons.share_rounded,
            outlined: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onPressed: () {
              SoundService.instance.play(Sfx.click);
              final box = context.findRenderObject() as RenderBox?;
              final origin = box == null
                  ? const Rect.fromLTWH(0, 0, 1, 1)
                  : box.localToGlobal(Offset.zero) & box.size;
              Share.share(
                'تعال العب معي كوت بو ٤! ادخل التطبيق واختر "انضم بكود" واكتب: ${room.code}',
                sharePositionOrigin: origin,
              );
            },
          ),
        ],
      ),
    );

    final mySeat = room.seatOf(_userId);
    final seatsGrid = GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.40,
      children: [
        for (final seat in const [0, 1, 2, 3])
          _SeatTile(
            seat: seat,
            info: room.seats[seat],
            isMe: seat == mySeat,
            canEdit: isHost && seat != mySeat,
            onToggleBot: (bot) => _cubit.setBot(seat, bot),
            onTakeSeat: () => _cubit.switchSeat(seat),
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
                            'المقاعد المتقابلة فريق واحد. اضغط على أي مقعد شاغر لتغيير مكانك وفريقك.',
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
                    'اللاعبان المتقابلان فريق واحد. اضغط على أي مقعد شاغر لتغيير مكانك وفريقك.',
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
    required this.onTakeSeat,
  });

  final int seat;
  final RoomSeat? info;
  final bool isMe;
  final bool canEdit;
  final ValueChanged<bool> onToggleBot;
  final VoidCallback onTakeSeat;

  @override
  Widget build(BuildContext context) {
    final team = seat % 2;
    final isTeam1 = team == 0;
    final seatInfo = info;
    final canTake = !isMe && (seatInfo == null || seatInfo.isBot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canTake
              ? () {
                  SoundService.instance.play(Sfx.click);
                  SoundService.instance.tap();
                  onTakeSeat();
                }
              : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 3),
                if (seatInfo == null) ...[
                  const Icon(Icons.person_add_alt_1_rounded, color: Colors.white30, size: 20),
                  const SizedBox(height: 1),
                  const Text('مقعد شاغر', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ] else ...[
                  Icon(
                    seatInfo.isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                    color: isMe ? AppColors.goldLight : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    seatInfo.isBot ? seatInfo.name : (isMe ? '${seatInfo.name} (أنت)' : seatInfo.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isMe ? AppColors.goldLight : Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                // أزرار التحكم: الانتقال للمقعد / إدارة البوت
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canTake)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          SoundService.instance.play(Sfx.click);
                          SoundService.instance.tap();
                          onTakeSeat();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withAlpha(45),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withAlpha(150)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 12, color: AppColors.goldLight),
                              SizedBox(width: 3),
                              Text(
                                'انتقل هنا',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (canTake && canEdit && (seatInfo == null || seatInfo.isBot))
                      const SizedBox(width: 4),
                    if (canEdit && (seatInfo == null || seatInfo.isBot))
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          SoundService.instance.play(Sfx.click);
                          onToggleBot(seatInfo == null);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            seatInfo == null ? '+ بوت' : 'حذف البوت',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: seatInfo == null ? Colors.white70 : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
