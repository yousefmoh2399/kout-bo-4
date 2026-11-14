import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/game_bloc.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/stats_repository.dart';
import 'effects.dart';
import 'game_page.dart';
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.gold,
                          child: Text(
                            auth.name.isEmpty ? '?' : auth.name.characters.first,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              FutureBuilder<PlayerStats?>(
                                future: _stats,
                                builder: (context, snap) {
                                  final st = snap.data;
                                  return Text(
                                    st == null ? (auth.isGuest ? 'ضيف' : 'لاعب') : 'لعبت ${st.games} • فزت ${st.wins}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'طريقة اللعب',
                          icon: const Icon(Icons.menu_book_rounded),
                          onPressed: () => Navigator.push(context, appRoute<void>(const RulesPage())),
                        ),
                        IconButton(
                          tooltip: 'الإعدادات',
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () => Navigator.push(context, appRoute<void>(const SettingsPage())),
                        ),
                        IconButton(
                          tooltip: 'خروج',
                          icon: const Icon(Icons.logout_rounded),
                          onPressed: () => context.read<AuthCubit>().signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Center(
                      child: Text('♠ ♥ ♦ ♣',
                          style: TextStyle(fontSize: 22, color: AppColors.gold, letterSpacing: 6)),
                    ),
                    Center(
                      child: Text(
                        'كوت بو ٤',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    GoldButton(label: 'العب ضد البوتات', icon: Icons.smart_toy_rounded, onPressed: _playSolo),
                    const SizedBox(height: 12),
                    GoldButton(
                      label: 'إنشاء غرفة وادعُ أصحابك',
                      icon: Icons.group_add_rounded,
                      outlined: true,
                      onPressed: online ? _createRoom : null,
                    ),
                    const SizedBox(height: 12),
                    GoldButton(
                      label: 'انضم بكود',
                      icon: Icons.vpn_key_rounded,
                      outlined: true,
                      onPressed: online ? _joinRoom : null,
                    ),
                    if (!online)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'اللعب أونلاين غير مفعّل: اضبط مفاتيح Supabase.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
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
