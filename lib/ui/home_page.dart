import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/game_bloc.dart';
import '../core/config.dart';
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
  }

  void _refresh() {
    _stats = context.read<StatsRepository>().summary();
    final uid = context.read<AuthCubit>().state.userId;
    if (AppConfig.isOnlineConfigured && uid != null && uid != 'local') {
      _activeRoom = RoomRepository(Supabase.instance.client).findMyActiveRoom(uid);
    } else {
      _activeRoom = null;
    }
  }

  Future<void> _playSolo() async {
    final settings = await showGameSettingsSheet(context, confirmLabel: 'ابدأ اللعب');
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

  Future<void> _createRoom() async {
    final settings = await showGameSettingsSheet(context, confirmLabel: 'إنشاء الغرفة');
    if (settings == null || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(create: settings)),
    );
    if (mounted) setState(_refresh);
  }

  Future<void> _joinRoom() async {
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
        style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.bold),
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
          onPressed: () => Navigator.pop(context, controller.text.trim().toUpperCase()),
        ),
      ],
    );
    controller.dispose();
    if (code == null || code.length < 4 || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(joinCode: code)),
    );
    if (mounted) setState(_refresh);
  }

  Future<void> _rejoinRoom(Room room) async {
    SoundService.instance.play(Sfx.click);
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(joinCode: room.code)),
    );
    if (mounted) setState(_refresh);
  }

  void _openSettings() {
    SoundService.instance.play(Sfx.click);
    Navigator.push(context, appRoute<void>(const SettingsPage())).then((_) {
      if (mounted) setState(() => _stats = context.read<StatsRepository>().summary());
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = AppConfig.isOnlineConfigured;
    final auth = context.watch<AuthCubit>().state;

    return Scaffold(
      body: FeltBackground(
        animated: true,
        child: SafeArea(
          child: Column(
            children: [
              // 1. الشريط العلوي الملكي (ملف اللاعب + أزرار التنقل السريع)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: LayoutBuilder(
                  builder: (context, topC) {
                    final compact = topC.maxWidth < 540;
                    return Row(
                      children: [
                        Flexible(
                          child: _ProfilePill(
                            name: auth.name,
                            isGuest: auth.isGuest,
                            statsFuture: _stats,
                            onTap: _openSettings,
                          ),
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
                        ] else ...[
                          _NavIconCircle(
                            tooltip: 'سجل المباريات',
                            icon: Icons.history_rounded,
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              showMatchHistorySheet(context);
                            },
                          ),
                          const SizedBox(width: 6),
                          _NavIconCircle(
                            tooltip: 'المتصدرون',
                            icon: Icons.emoji_events_rounded,
                            onTap: () {
                              SoundService.instance.play(Sfx.click);
                              showLeaderboardSheet(context);
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                        _NavIconCircle(
                          tooltip: 'طريقة اللعب',
                          icon: Icons.menu_book_rounded,
                          onTap: () {
                            SoundService.instance.play(Sfx.click);
                            Navigator.push(context, appRoute<void>(const RulesPage()));
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
                          tooltip: 'خروج',
                          icon: Icons.logout_rounded,
                          color: Colors.white60,
                          onTap: () {
                            SoundService.instance.play(Sfx.click);
                            context.read<AuthCubit>().signOut();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              // شريط الغرفة النشطة للعودة السريعة إذا كان اللاعب منضماً لغرفة حالياً
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
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _rejoinRoom(room),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xEE2B2007), Color(0xEE141A0E)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gold, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.meeting_room_rounded, color: AppColors.goldLight, size: 20),
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
                                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.goldLight, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // 2. قلب الصفحة (تصميم مزدوج متوازن في الوضع الأفقي)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 560;
                    if (isWide) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _HeroShowcase(statsFuture: _stats),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 5,
                                  child: _PlayPanel(
                                    online: online,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          _HeroShowcase(statsFuture: _stats),
                          const SizedBox(height: 22),
                          _PlayPanel(
                            online: online,
                            onPlaySolo: _playSolo,
                            onCreateRoom: _createRoom,
                            onJoinRoom: _joinRoom,
                          ),
                        ],
                      ),
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
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
          decoration: BoxDecoration(
            color: const Color(0xC8041B12),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.gold.withAlpha(110), width: 1.1),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 1.3),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(
                    color: Color(0xFF1E1304),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, height: 1.1),
                  ),
                  FutureBuilder<PlayerStats?>(
                    future: statsFuture,
                    builder: (context, snap) {
                      final st = snap.data;
                      return Text(
                        st == null
                            ? (isGuest ? 'حساب ضيف' : 'لاعب مميز')
                            : 'فوز ${st.wins} من ${st.games}',
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 10.5, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
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
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xC0041B12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withAlpha(90), width: 1),
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
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xC0041B12),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, size: 17, color: color ?? AppColors.goldLight),
          ),
        ),
      ),
    );
  }
}

/// الواجهة الترحيبية اليسرى: مروحة أوراق ثلاثية الأبعاد + الشعار الملكي.
class _HeroShowcase extends StatefulWidget {
  const _HeroShowcase({required this.statsFuture});

  final Future<PlayerStats?>? statsFuture;

  @override
  State<_HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<_HeroShowcase> with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

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
        // مروحة أوراق الديوانية الفاخرة
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, child) {
            final dy = sin(_floatCtrl.value * pi) * 4.5;
            return Transform.translate(offset: Offset(0, -dy), child: child);
          },
          child: SizedBox(
            height: 102,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 24,
                  top: 14,
                  child: Transform.rotate(
                    angle: -0.22,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.hearts, Rank.king),
                      width: 54,
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 14,
                  child: Transform.rotate(
                    angle: 0.22,
                    child: const PlayingCardView(
                      card: PlayingCard.suited(Suit.spades, Rank.ace),
                      width: 54,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  child: Transform.rotate(
                    angle: 0.02,
                    child: const PlayingCardView(
                      card: PlayingCard.joker(JokerKind.red),
                      width: 58,
                      highlighted: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'كوت بو ٤',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.goldLight,
                fontWeight: FontWeight.w900,
                fontSize: 34,
                height: 1.05,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(180), blurRadius: 16, offset: const Offset(0, 4)),
                  Shadow(color: AppColors.gold.withAlpha(130), blurRadius: 24),
                ],
              ),
        ),
        const SizedBox(height: 3),
        const Text(
          'ديوانية الورق الخليجية الأصيلة',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<PlayerStats?>(
          future: widget.statsFuture,
          builder: (context, snap) {
            final st = snap.data;
            final games = st?.games ?? 0;
            final wins = st?.wins ?? 0;
            final rate = games == 0 ? 0 : ((wins / games) * 100).round();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(90),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withAlpha(75)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniStat('المباريات', '$games', Colors.white),
                  _sep(),
                  _miniStat('الانتصارات', '$wins', const Color(0xFF48BB78)),
                  _sep(),
                  _miniStat('نسبة الفوز', '$rate%', AppColors.goldLight),
                ],
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
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, height: 1.1)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
      ],
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.white12,
      );
}

/// لوحة أوضاع اللعب اليمنى (لعب فردي + غرف الأونلاين).
class _PlayPanel extends StatelessWidget {
  const _PlayPanel({
    required this.online,
    required this.onPlaySolo,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool online;
  final VoidCallback onPlaySolo;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.gold.withAlpha(110),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // زر اللعب الفردي البارز
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                SoundService.instance.play(Sfx.click);
                SoundService.instance.impact();
                onPlaySolo();
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withAlpha(150), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: AppColors.gold.withAlpha(90), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1304).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1E1304), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'العب ضد البوتات',
                            style: TextStyle(
                              color: Color(0xFF1E1304),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'طاولة سريعة وذكاء اصطناعي متقدم',
                            style: TextStyle(
                              color: Color(0xFF3E2908),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1E1304), size: 16),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'اللعب الجماعي أونلاين',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: online ? AppColors.goldLight : Colors.white38,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: GoldButton(
                  label: 'إنشاء غرفة',
                  icon: Icons.group_add_rounded,
                  outlined: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onPressed: online ? onCreateRoom : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoldButton(
                  label: 'انضم بكود',
                  icon: Icons.vpn_key_rounded,
                  outlined: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onPressed: online ? onJoinRoom : null,
                ),
              ),
            ],
          ),

          if (!online) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.white54),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'اللعب أونلاين غير مفعّل: اضبط مفاتيح Supabase.',
                      style: TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// متاح للاستخدام في الأماكن التي تحتاج العميل.
SupabaseClient? maybeClient() {
  if (!AppConfig.isOnlineConfigured) return null;
  return Supabase.instance.client;
}
