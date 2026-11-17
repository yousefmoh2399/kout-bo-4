import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/game_bloc.dart';
import '../core/config.dart';
import '../core/connectivity_service.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/room.dart';
import '../data/room_repository.dart';
import '../data/stats_repository.dart';
import '../domain/card.dart';
import 'card_view.dart';
import 'effects.dart';
import 'game_page.dart';
import 'history_leaderboard_sheet.dart';
import 'room_page.dart';
import 'rules_page.dart';
import 'settings_page.dart';
import 'settings_sheet.dart';
import 'store_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<PlayerStats?>? _stats;
  Future<Room?>? _activeRoom;

  @override
  void initState() {
    super.initState();
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthCubit>().refreshCoins();
    });
  }

  void _refresh() {
    _stats = context.read<StatsRepository>().summary();
    final uid = context.read<AuthCubit>().state.userId;
    if (AppConfig.isOnlineConfigured && uid != null && uid != 'local') {
      _activeRoom =
          RoomRepository(Supabase.instance.client).findMyActiveRoom(uid);
    } else {
      _activeRoom = null;
    }
  }

  Future<void> _playSolo() async {
    final settings =
        await showGameSettingsSheet(context, confirmLabel: 'ابدأ اللعب');
    if (settings == null || !mounted) return;
    final name = context.read<AuthCubit>().state.name;
    final bloc = GameBloc(
      turnSeconds: settings.turnSeconds,
      matchMinutes: settings.matchMinutes,
      targetScore: settings.targetScore,
      botDifficulty: settings.botDifficulty,
      names: [name, 'خصم ١', 'شريكك', 'خصم ٢'],
    )..add(const GameStarted());
    await Navigator.push(
      context,
      appRoute<void>(GamePage(bloc: bloc)),
    );
    if (mounted) setState(_refresh);
  }

  void _showOfflineActionDialog({required String actionName}) {
    SoundService.instance.play(Sfx.click);
    showLuxuryDialog<void>(
      context: context,
      title: 'لا يوجد اتصال بالإنترنت',
      icon: Icons.wifi_off_rounded,
      accentColor: const Color(0xFFF59E0B),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$actionName غير متاح لعدم توفر اتصال بالإنترنت.\n\nوضع الأوفلاين مفعّل حالياً — يمكنك الاستمتاع بلعب كوت بو ٤ الفردي ضد البوتات الذكية بدون نت!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
        GoldButton(
          label: 'ابدأ اللعب الفردي',
          icon: Icons.play_arrow_rounded,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () {
            Navigator.pop(context);
            _playSolo();
          },
        ),
      ],
    );
  }

  Future<void> _showGuestBlockedDialog({
    required String title,
    required String actionName,
  }) async {
    SoundService.instance.play(Sfx.click);
    await showLuxuryDialog<void>(
      context: context,
      title: title,
      icon: Icons.lock_person_rounded,
      accentColor: AppColors.gold,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withAlpha(90)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_rounded, color: AppColors.goldLight, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'احصل على ٥٠٠ نقطة ترحيبية مجاناً 🎁',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'أنت تلعب حالياً كـ (ضيف / زائر).\n\nميزة ($actionName) متاحة فقط للأعضاء المسجلين لحفظ النقاط والنتائج.\n\nسجّل حسابك الآن واحصل على ٥٠٠ نقطة ترحيبية مجاناً لفتح الغرف واللعب مع الربع!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
        GoldButton(
          label: 'سجّل حسابك (٥٠٠ 🎁)',
          icon: Icons.app_registration_rounded,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onPressed: () {
            Navigator.pop(context);
            context.read<AuthCubit>().signOut();
          },
        ),
      ],
    );
  }

  Future<void> _createRoom() async {
    if (!ConnectivityService.instance.isOnline) {
      _showOfflineActionDialog(actionName: 'إنشاء ديوانية أونلاين');
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth.isGuest || auth.userId == null || auth.userId == 'local') {
      _showGuestBlockedDialog(
        title: 'تسجيل الحساب مطلوب',
        actionName: 'إنشاء ديوانية أونلاين',
      );
      return;
    }
    final userCoins = auth.coins;
    final settings = await showGameSettingsSheet(
      context,
      confirmLabel: 'إنشاء الغرفة',
      isOnlineRoom: true,
      userCoins: userCoins,
      isGuest: false,
    );
    if (settings == null || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(create: settings)),
    );
    if (mounted) {
      context.read<AuthCubit>().refreshCoins();
      setState(_refresh);
    }
  }

  Future<void> _joinRoom() async {
    if (!ConnectivityService.instance.isOnline) {
      _showOfflineActionDialog(actionName: 'الانضمام لديوانية أونلاين');
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth.isGuest || auth.userId == null || auth.userId == 'local') {
      _showGuestBlockedDialog(
        title: 'تسجيل الحساب مطلوب',
        actionName: 'الانضمام لديوانية أونلاين',
      );
      return;
    }
    final controller = TextEditingController();
    final code = await showLuxuryDialog<String>(
      context: context,
      title: 'انضم لغرفة',
      icon: Icons.vpn_key_rounded,
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        maxLength: 5,
        style: const TextStyle(
          fontSize: 26,
          letterSpacing: 8,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(hintText: 'XXXXX', counterText: ''),
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
        GoldButton(
          label: 'انضم',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () =>
              Navigator.pop(context, controller.text.trim().toUpperCase()),
        ),
      ],
    );
    controller.dispose();
    if (code == null || code.length < 4 || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(joinCode: code)),
    );
    if (mounted) {
      context.read<AuthCubit>().refreshCoins();
      setState(_refresh);
    }
  }

  Future<void> _rejoinRoom(Room room) async {
    final auth = context.read<AuthCubit>().state;
    if (auth.isGuest || auth.userId == null || auth.userId == 'local') {
      _showGuestBlockedDialog(
        title: 'تسجيل الحساب مطلوب',
        actionName: 'الانضمام لديوانية أونلاين',
      );
      return;
    }
    SoundService.instance.play(Sfx.click);
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(joinCode: room.code)),
    );
    if (mounted) {
      context.read<AuthCubit>().refreshCoins();
      setState(_refresh);
    }
  }

  void _openSettings() {
    SoundService.instance.play(Sfx.click);
    Navigator.push(context, appRoute<void>(const SettingsPage())).then((_) {
      if (mounted) {
        setState(() {
          _stats = context.read<StatsRepository>().summary();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = AppConfig.isOnlineConfigured;
    final auth = context.watch<AuthCubit>().state;

    return Scaffold(
      body: _HomeDiwaniyaBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              // 1. الشريط العلوي الفاخر (ملف اللاعب + أزرار التنقل السريع)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: LayoutBuilder(
                  builder: (context, topC) {
                    final compact = topC.maxWidth < 560;
                    return Row(
                      children: [
                        Expanded(
                          child: _ProfilePill(
                            name: auth.name,
                            isGuest: auth.isGuest,
                            statsFuture: _stats,
                            onTap: _openSettings,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CoinsPill(
                          coins: auth.coins,
                          isGuest: auth.isGuest,
                          onTap: () async {
                            if (auth.isGuest) {
                              _showGuestBlockedDialog(
                                title: 'رصيد نقاط الأعضاء',
                                actionName: 'شحن واستخدام النقاط',
                              );
                              return;
                            }
                            if (!ConnectivityService.instance.isOnline) {
                              SoundService.instance.play(Sfx.click);
                              showLuxuryDialog<void>(
                                context: context,
                                title: 'المتجر غير متاح بدون إنترنت',
                                icon: Icons.wifi_off_rounded,
                                accentColor: const Color(0xFFF59E0B),
                                content: const Text(
                                  'متجر النقاط وعمليات الشراء تتطلب اتصالاً فعّالاً بالإنترنت.\nيرجى الاتصال بالإنترنت والعودة للمتجر.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                actions: [
                                  GoldButton(
                                    label: 'حسناً',
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              );
                              return;
                            }
                            final authCubit = context.read<AuthCubit>();
                            SoundService.instance.play(Sfx.click);
                            await StorePage.show(context);
                            if (mounted) authCubit.refreshCoins();
                          },
                        ),
                        const SizedBox(width: 8),
                        if (!compact) ...[
                          _NavActionPill(
                            icon: Icons.history_rounded,
                            label: 'السجل',
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              showMatchHistorySheet(context);
                            },
                          ),
                          const SizedBox(width: 8),
                          _NavActionPill(
                            icon: Icons.emoji_events_rounded,
                            label: 'المتصدرون',
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              showLeaderboardSheet(context);
                            },
                          ),
                          const SizedBox(width: 8),
                          _NavIconCircle(
                            tooltip: 'قوانين كوت بو ٤',
                            icon: Icons.menu_book_rounded,
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              Navigator.push(
                                context,
                                appRoute<void>(const RulesPage()),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _NavIconCircle(
                            tooltip: 'الإعدادات',
                            icon: Icons.settings_rounded,
                            onTap: _openSettings,
                          ),
                          const SizedBox(width: 6),
                          _NavIconCircle(
                            tooltip: 'تسجيل الخروج',
                            icon: Icons.logout_rounded,
                            color: Colors.white70,
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              context.read<AuthCubit>().signOut();
                            },
                          ),
                        ] else ...[
                          _NavIconCircle(
                            tooltip: 'المتصدرون',
                            icon: Icons.emoji_events_rounded,
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              showLeaderboardSheet(context);
                            },
                          ),
                          const SizedBox(width: 6),
                          _NavIconCircle(
                            tooltip: 'الإعدادات',
                            icon: Icons.settings_rounded,
                            onTap: _openSettings,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              // شريط حالة عدم الاتصال بالإنترنت والتحويل لوضع الأوفلاين
              ValueListenableBuilder<bool>(
                valueListenable: ConnectivityService.instance.isOnlineNotifier,
                builder: (context, isOnline, _) {
                  if (isOnline) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xEE452605), Color(0xEE2A1702)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withAlpha(45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFFBBF24),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'لا يوجد اتصال بالإنترنت • وضع الأوفلاين مفعّل',
                                  style: TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'طاولة اللعب الفردي ضد البوتات متاحة وتعمل بدون نت.',
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          GoldButton(
                            label: 'العب فردي',
                            icon: Icons.play_arrow_rounded,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            onPressed: _playSolo,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // شريط العودة السريعة للغرفة النشطة
              if (_activeRoom != null)
                FutureBuilder<Room?>(
                  future: _activeRoom,
                  builder: (context, snap) {
                    final room = snap.data;
                    if (room == null) return const SizedBox.shrink();
                    final isHost = room.hostId == auth.userId;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _rejoinRoom(room),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xEE332308), Color(0xEE181F12)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.gold,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.meeting_room_rounded,
                                  color: AppColors.goldLight,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isHost
                                        ? 'غرفتك (${room.code}) ${room.isPlaying ? "جارية الآن" : "بانتظار اللاعبين"} — اضغط للعودة'
                                        : 'أنت في الغرفة (${room.code}) — اضغط للعودة',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.goldLight,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppColors.goldLight,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // 2. محتوى الصفحة المتجاوب مع الطولي والعرضي
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService.instance.isOnlineNotifier,
                  builder: (context, isOnline, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 580;
                        if (isWide) {
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 920),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _HeroShowcase(
                                        statsFuture: _stats,
                                        compact: true,
                                      ),
                                    ),
                                    const SizedBox(width: 26),
                                    Expanded(
                                      flex: 6,
                                      child: _PlayModesSection(
                                        online: online && isOnline,
                                        isDeviceOnline: isOnline,
                                        onPlaySolo: _playSolo,
                                        onCreateRoom: _createRoom,
                                        onJoinRoom: _joinRoom,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                          child: Column(
                            children: [
                              _HeroShowcase(statsFuture: _stats, compact: false),
                              const SizedBox(height: 20),
                              _PlayModesSection(
                                online: online && isOnline,
                                isDeviceOnline: isOnline,
                                onPlaySolo: _playSolo,
                                onCreateRoom: _createRoom,
                                onJoinRoom: _joinRoom,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خلفية الديوانية الكويتية الملكية للشاشة الرئيسية.
class _HomeDiwaniyaBackdrop extends StatelessWidget {
  const _HomeDiwaniyaBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.35),
          radius: 1.25,
          colors: [
            Color(0xFF15382E),
            Color(0xFF0B1F1D),
            Color(0xFF061014),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _HomeSaduPatternPainter()),
          child,
        ],
      ),
    );
  }
}

class _HomeSaduPatternPainter extends CustomPainter {
  const _HomeSaduPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldLine = Paint()
      ..color = AppColors.gold.withAlpha(14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final crimsonDiamond = Paint()
      ..color = const Color(0xFF8E2430).withAlpha(22)
      ..style = PaintingStyle.fill;

    // زخرفة هندسية هادئة في الخلفية
    const spacing = 76.0;
    for (double y = 20; y < size.height; y += spacing) {
      for (double x = 20; x < size.width; x += spacing) {
        _diamond(canvas, Offset(x, y), 24, goldLine);
        _diamond(canvas, Offset(x, y), 5, crimsonDiamond);
      }
    }

    // هالة دائرية ذهبية خفيفة خلف الشعار العلوي
    final cx = size.width / 2;
    final cy = size.height * 0.26;
    final ringPaint = Paint()
      ..color = AppColors.gold.withAlpha(22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), min(size.width, size.height) * 0.28, ringPaint);
  }

  void _diamond(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.name,
    required this.isGuest,
    required this.statsFuture,
    required this.onTap,
  });

  final String name;
  final bool isGuest;
  final Future<PlayerStats?>? statsFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xDD0D2922), Color(0xDD061512)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.gold.withAlpha(120),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.goldLight,
                      AppColors.gold,
                      AppColors.goldDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(
                    color: Color(0xFF1E1304),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<PlayerStats?>(
                      future: statsFuture,
                      builder: (context, snap) {
                        final st = snap.data;
                        return Text(
                          st == null
                              ? (isGuest ? 'ضيف الديوانية' : 'عضو الديوانية')
                              : 'فوز ${st.wins} من ${st.games}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
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
}

class _CoinsPill extends StatelessWidget {
  const _CoinsPill({
    required this.coins,
    required this.onTap,
    this.isGuest = false,
  });

  final int coins;
  final VoidCallback onTap;
  final bool isGuest;

  String _format(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xEE1E1408), Color(0xEE332408)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withAlpha(50),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGuest
                    ? Icons.card_giftcard_rounded
                    : Icons.monetization_on_rounded,
                size: 16,
                color: AppColors.goldLight,
              ),
              const SizedBox(width: 4),
              Text(
                isGuest ? 'ضيف (٠)' : _format(coins),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldLight,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                ),
                child: const Icon(
                  Icons.add,
                  size: 11,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavActionPill extends StatelessWidget {
  const _NavActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC0A221C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold.withAlpha(95), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.goldLight),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconCircle extends StatelessWidget {
  const _NavIconCircle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC0A221C),
              border: Border.all(
                color: AppColors.gold.withAlpha(75),
                width: 1.0,
              ),
            ),
            child: Icon(icon, size: 17, color: color ?? AppColors.goldLight),
          ),
        ),
      ),
    );
  }
}

/// الشعار الملكي لـ "كوت بو ٤" مع ميدالية الديوانية وشريط الإحصائيات.
class _HeroShowcase extends StatefulWidget {
  const _HeroShowcase({
    required this.statsFuture,
    required this.compact,
  });

  final Future<PlayerStats?>? statsFuture;
  final bool compact;

  @override
  State<_HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<_HeroShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ميدالية أوراق الديوانية الملكية
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, child) {
            final dy = sin(_floatCtrl.value * pi) * 4.0;
            return Transform.translate(offset: Offset(0, -dy), child: child);
          },
          child: SizedBox(
            height: widget.compact ? 112 : 124,
            width: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // هالة ذهبية خلف الأوراق
                Container(
                  width: widget.compact ? 96 : 108,
                  height: widget.compact ? 96 : 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withAlpha(75),
                        AppColors.gold.withAlpha(12),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(90),
                      width: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 18,
                  child: Transform.rotate(
                    angle: -0.32,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.diamonds, Rank.ace),
                      width: 48,
                    ),
                  ),
                ),
                Positioned(
                  left: 52,
                  top: 10,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.hearts, Rank.king),
                      width: 52,
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 18,
                  child: Transform.rotate(
                    angle: 0.32,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.clubs, Rank.ten),
                      width: 48,
                    ),
                  ),
                ),
                Positioned(
                  right: 52,
                  top: 10,
                  child: Transform.rotate(
                    angle: 0.12,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.spades, Rank.ace),
                      width: 52,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  child: const PlayingCardView(
                    card: PlayingCard.joker(JokerKind.red),
                    width: 56,
                    highlighted: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // شارة العنوان الملكية
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withAlpha(130)),
              ),
              child: const Text(
                '٤',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'كوت بو ٤',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.compact ? 30 : 34,
                    height: 1.05,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(200),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      Shadow(
                        color: AppColors.gold.withAlpha(120),
                        blurRadius: 22,
                      ),
                    ],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'ديوانية الورق الكويتية الأصيلة',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        // شريط الإحصائيات الزجاجي المذهب
        FutureBuilder<PlayerStats?>(
          future: widget.statsFuture,
          builder: (context, snap) {
            final st = snap.data;
            final games = st?.games ?? 0;
            final wins = st?.wins ?? 0;
            final rate = games == 0 ? 0 : ((wins / games) * 100).round();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xCC0D2620), Color(0xCC061411)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withAlpha(90)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniStat('المباريات', '$games', Colors.white),
                    _sep(),
                    _miniStat('الانتصارات', '$wins', const Color(0xFF4BE0A8)),
                    _sep(),
                    _miniStat('نسبة الفوز', '$rate%', AppColors.goldLight),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white12,
      );
}

/// بطاقات أوضاع اللعب الثلاث الفاخرة (لعب فردي، إنشاء ديوانية، انضمام بكود).
class _PlayModesSection extends StatelessWidget {
  const _PlayModesSection({
    required this.online,
    this.isDeviceOnline = true,
    required this.onPlaySolo,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool online;
  final bool isDeviceOnline;
  final VoidCallback onPlaySolo;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. بطاقة اللعب الفردي الملكية
        _LuxuryModeCard(
          title: 'اللعب الفردي • طاولة فورية',
          subtitle: 'نافس بوتات الديوانية بمستوى عادي أو محترف',
          badge: 'بدون إنترنت',
          icon: Icons.style_rounded,
          gradientColors: const [
            Color(0xFFE5C158),
            Color(0xFFC89B2B),
            Color(0xFF9C7214),
          ],
          darkText: true,
          onTap: () {
            SoundService.instance.play(Sfx.click);
            SoundService.instance.impact();
            onPlaySolo();
          },
        ),
        const SizedBox(height: 12),

        // 2. بطاقتا اللعب الجماعي أونلاين جنباً إلى جنب
        Row(
          children: [
            Expanded(
              child: _LuxurySubModeCard(
                title: 'إنشاء ديوانية',
                subtitle: 'افتح غرفة وشارك الكود',
                icon: Icons.add_home_work_rounded,
                accentColor: const Color(0xFF4BE0A8),
                gradientColors: const [
                  Color(0xEE143D32),
                  Color(0xEE09211B),
                ],
                enabled: online,
                badge: !isDeviceOnline ? 'أوفلاين' : null,
                onTap: () {
                  SoundService.instance.play(Sfx.click);
                  onCreateRoom();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LuxurySubModeCard(
                title: 'انضم بكود',
                subtitle: 'ادخل كود غرفة ربعك',
                icon: Icons.vpn_key_rounded,
                accentColor: AppColors.goldLight,
                gradientColors: const [
                  Color(0xEE381D24),
                  Color(0xEE1E0E13),
                ],
                enabled: online,
                badge: !isDeviceOnline ? 'أوفلاين' : null,
                onTap: () {
                  SoundService.instance.play(Sfx.click);
                  onJoinRoom();
                },
              ),
            ),
          ],
        ),

        if (!online) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !isDeviceOnline
                    ? const Color(0xFFF59E0B).withAlpha(120)
                    : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  !isDeviceOnline ? Icons.wifi_off_rounded : Icons.info_outline,
                  size: 14,
                  color: !isDeviceOnline
                      ? const Color(0xFFFBBF24)
                      : Colors.white54,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    !isDeviceOnline
                        ? 'لا يوجد اتصال بالإنترنت: وضع الأوفلاين مفعّل (طاولة اللعب الفردي ضد البوتات متاحة).'
                        : 'اللعب أونلاين غير مفعّل: اضبط مفاتيح Supabase.',
                    style: TextStyle(
                      color: !isDeviceOnline
                          ? const Color(0xFFFDE68A)
                          : Colors.white54,
                      fontSize: 10.5,
                      fontWeight: !isDeviceOnline
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LuxuryModeCard extends StatelessWidget {
  const _LuxuryModeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradientColors,
    required this.darkText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradientColors;
  final bool darkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = darkText ? const Color(0xFF1B1102) : Colors.white;
    final subFg = darkText ? const Color(0xFF3E2908) : Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withAlpha(160),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withAlpha(95),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fg.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fg, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: fg,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: fg.withAlpha(24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: fg,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subFg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withAlpha(24),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: fg,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxurySubModeCard extends StatelessWidget {
  const _LuxurySubModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.enabled,
    this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final bool enabled;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withAlpha(130),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33F59E0B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withAlpha(150),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: accentColor.withAlpha(180),
                        size: 14,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// متاح للاستخدام في الأماكن التي تحتاج العميل.
SupabaseClient? maybeClient() {
  if (!AppConfig.isOnlineConfigured) return null;
  return Supabase.instance.client;
}
