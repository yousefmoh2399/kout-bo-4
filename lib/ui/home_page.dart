import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/game_bloc.dart';
import '../core/config.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/stats_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _stats = context.read<StatsRepository>().summary();
  }

  Future<void> _playSolo() async {
    final settings = await showGameSettingsSheet(context, confirmLabel: 'ابدأ اللعب');
    if (settings == null || !mounted) return;
    final name = context.read<AuthCubit>().state.name;
    final bloc = GameBloc(
      turnSeconds: settings.turnSeconds,
      targetScore: settings.targetScore,
      names: [name, 'خصم ١', 'شريكك', 'خصم ٢'],
    )..add(const GameStarted());
    await Navigator.push(
      context,
      appRoute<void>(GamePage(bloc: bloc)),
    );
    if (mounted) setState(() => _stats = context.read<StatsRepository>().summary());
  }

  Future<void> _createRoom() async {
    final settings = await showGameSettingsSheet(context, confirmLabel: 'إنشاء الغرفة');
    if (settings == null || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(create: settings)),
    );
    if (mounted) setState(() => _stats = context.read<StatsRepository>().summary());
  }

  Future<void> _joinRoom() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('انضم لغرفة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 5,
          style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: 'XXXXX', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase()),
            child: const Text('انضم'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.length < 4 || !mounted) return;
    await Navigator.push(
      context,
      appRoute<void>(RoomPage(joinCode: code)),
    );
    if (mounted) setState(() => _stats = context.read<StatsRepository>().summary());
  }

  @override
  Widget build(BuildContext context) {
    final online = AppConfig.isOnlineConfigured;
    final auth = context.watch<AuthCubit>().state;

    return Scaffold(
      body: FeltBackground(
        animated: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 580;

              final profileCard = GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderColor: AppColors.gold.withAlpha(90),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withAlpha(100),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        auth.name.isEmpty ? '?' : auth.name.characters.first,
                        style: const TextStyle(
                          color: Color(0xFF1E1304),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FutureBuilder<PlayerStats?>(
                            future: _stats,
                            builder: (context, snap) {
                              final st = snap.data;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events_rounded,
                                    size: 14,
                                    color: AppColors.gold.withAlpha(200),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      st == null
                                          ? (auth.isGuest ? 'حساب ضيف' : 'لاعب مميز')
                                          : 'لعبت ${st.games} • فزت ${st.wins}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'طريقة اللعب',
                      icon: const Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 20),
                      onPressed: () {
                        SoundService.instance.play(Sfx.click);
                        Navigator.push(context, appRoute<void>(const RulesPage()));
                      },
                    ),
                    IconButton(
                      tooltip: 'الإعدادات',
                      icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                      onPressed: () {
                        SoundService.instance.play(Sfx.click);
                        Navigator.push(context, appRoute<void>(const SettingsPage()));
                      },
                    ),
                    IconButton(
                      tooltip: 'خروج',
                      icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                      onPressed: () {
                        SoundService.instance.play(Sfx.click);
                        context.read<AuthCubit>().signOut();
                      },
                    ),
                  ],
                ),
              );

              final quickStatsButtons = Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        SoundService.instance.play(Sfx.click);
                        showMatchHistorySheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withAlpha(120)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: AppColors.goldLight),
                            SizedBox(width: 6),
                            Text(
                              'سجل المباريات',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        SoundService.instance.play(Sfx.click);
                        showLeaderboardSheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withAlpha(120)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.goldLight),
                            SizedBox(width: 6),
                            Text(
                              'المتصدرون',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );

              final headerTitle = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withAlpha(80), width: 1),
                    ),
                    child: const Text(
                      '♠  ♥  ♦  ♣',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.goldLight,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كوت بو ٤',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(160),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                            Shadow(
                              color: AppColors.gold.withAlpha(120),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                  ),
                  const Text(
                    'لعبة الورق الخليجية الأصيلة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );

              final playButtons = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoldButton(
                    label: 'العب ضد البوتات',
                    icon: Icons.smart_toy_rounded,
                    onPressed: _playSolo,
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'إنشاء غرفة وادعُ أصحابك',
                    icon: Icons.group_add_rounded,
                    outlined: true,
                    onPressed: online ? _createRoom : null,
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'انضم بكود الغرفة',
                    icon: Icons.vpn_key_rounded,
                    outlined: true,
                    onPressed: online ? _joinRoom : null,
                  ),
                  if (!online)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(60),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 15, color: Colors.white54),
                            SizedBox(width: 6),
                            Text(
                              'اللعب أونلاين غير مفعّل: اضبط مفاتيح Supabase.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );

              if (isWide) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                headerTitle,
                                const SizedBox(height: 16),
                                profileCard,
                                const SizedBox(height: 10),
                                quickStatsButtons,
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 4,
                            child: playButtons,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        profileCard,
                        const SizedBox(height: 12),
                        quickStatsButtons,
                        const SizedBox(height: 28),
                        headerTitle,
                        const SizedBox(height: 36),
                        playButtons,
                      ],
                    ),
                  ),
                ),
              );
            },
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
