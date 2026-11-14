import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/auth_cubit.dart';
import '../core/config.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/stats_repository.dart';
import 'effects.dart';
import 'history_leaderboard_sheet.dart';
import 'rules_page.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<PlayerStats?>? _statsFuture;
  bool _fastAnimations = false;
  bool _confirmExit = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _statsFuture = context.read<StatsRepository>().summary();
      _fastAnimations = prefs.getBool('pref_fast_animations') ?? false;
      _confirmExit = prefs.getBool('pref_confirm_exit') ?? true;
    });
  }

  Future<void> _setFastAnimations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_fast_animations', value);
    setState(() => _fastAnimations = value);
  }

  Future<void> _setConfirmExit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_confirm_exit', value);
    setState(() => _confirmExit = value);
  }

  Future<void> _editName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم اللاعب'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'الاسم الجديد',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty && context.mounted) {
      SoundService.instance.play(Sfx.click);
      context.read<AuthCubit>().updateName(newName);
      showSnack(context, 'تم تحديث الاسم بنجاح');
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('حذف الحساب نهائياً؟'),
        content: const Text('سيتم حذف حسابك وكل بياناتك المسجلة ولا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await cubit.deleteAccount();
    if (!context.mounted) return;
    if (done) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      showSnack(context, 'تعذر حذف الحساب، حاول لاحقاً');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>();
    final authState = auth.state;
    final canDelete = auth.online && authState.userId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة الإعدادات',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.goldLight),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: FeltBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
              // 1. بطاقة الملف الشخصي (Player Profile)
              _buildSectionTitle(Icons.account_circle_outlined, 'الملف الشخصي والحساب'),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: AppColors.gold.withAlpha(90), blurRadius: 10),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        authState.name.isEmpty ? '?' : authState.name.characters.first,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E1304),
                        ),
                      ),
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
                                  authState.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: 'تعديل الاسم',
                                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.gold),
                                onPressed: () => _editName(context, authState.name),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              authState.isGuest ? 'حساب ضيف (محلي)' : 'حساب مسجل بالبريد',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. إحصائيات اللاعب (Player Stats)
              _buildSectionTitle(Icons.insights_rounded, 'سجل وإحصائيات اللعب'),
              FutureBuilder<PlayerStats?>(
                future: _statsFuture,
                builder: (context, snap) {
                  final st = snap.data;
                  final games = st?.games ?? 0;
                  final wins = st?.wins ?? 0;
                  final losses = games - wins;
                  final winRate = games == 0 ? 0 : ((wins / games) * 100).round();

                  return GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('المباريات', '$games', AppColors.goldLight),
                            _buildDivider(),
                            _buildStatColumn('الانتصارات', '$wins', const Color(0xFF48BB78)),
                            _buildDivider(),
                            _buildStatColumn('الهزائم', '$losses', const Color(0xFFE53E3E)),
                            _buildDivider(),
                            _buildStatColumn('نسبة الفوز', '$winRate%', AppColors.gold),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Colors.white12),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.gold),
                                label: const Text('سجل المباريات', style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
                                onPressed: () {
                                  SoundService.instance.play(Sfx.click);
                                  showMatchHistorySheet(context);
                                },
                              ),
                            ),
                            Container(width: 1, height: 20, color: Colors.white12),
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.gold),
                                label: const Text('المتصدرون', style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
                                onPressed: () {
                                  SoundService.instance.play(Sfx.click);
                                  showLeaderboardSheet(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // 3. الصوتيات والاهتزاز (Audio & Haptics)
              _buildSectionTitle(Icons.volume_up_rounded, 'الصوت والمؤثرات اللمسية'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundService.instance.enabled,
                      builder: (context, on, _) => SwitchListTile(
                        secondary: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                        title: const Text('المؤثرات الصوتية', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('أصوات رمي الورق، التوزيع، والفوز'),
                        value: on,
                        activeThumbColor: AppColors.gold,
                        onChanged: (val) {
                          SoundService.instance.setEnabled(val);
                          SoundService.instance.play(Sfx.click);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    ValueListenableBuilder<double>(
                      valueListenable: SoundService.instance.volume,
                      builder: (context, vol, _) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, color: Colors.white70, size: 20),
                            Expanded(
                              child: Slider(
                                value: vol,
                                min: 0.0,
                                max: 1.0,
                                activeColor: AppColors.gold,
                                inactiveColor: Colors.white24,
                                onChanged: (val) => SoundService.instance.setVolume(val),
                                onChangeEnd: (_) => SoundService.instance.play(Sfx.click),
                              ),
                            ),
                            Text(
                              '${(vol * 100).round()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundService.instance.turnAlert,
                      builder: (context, alert, _) => SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.gold),
                        title: const Text('تنبيه حلول دورك', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('رنين ناعم عند بدء دورك باللعب'),
                        value: alert,
                        activeThumbColor: AppColors.gold,
                        onChanged: (val) {
                          SoundService.instance.setTurnAlert(val);
                          SoundService.instance.play(Sfx.turn);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundService.instance.haptics,
                      builder: (context, on, _) => SwitchListTile(
                        secondary: const Icon(Icons.vibration_rounded, color: AppColors.gold),
                        title: const Text('الاهتزاز اللمسي', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('نبضات لمسية خفيفة مع أفعال اللعب'),
                        value: on,
                        activeThumbColor: AppColors.gold,
                        onChanged: (val) {
                          SoundService.instance.setHaptics(val);
                          if (val) SoundService.instance.impact();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4. أسلوب وطاولة اللعب (Gameplay Preferences)
              _buildSectionTitle(Icons.style_rounded, 'أسلوب وطاولة اللعب'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.speed_rounded, color: AppColors.gold),
                      title: const Text('تسريع حركات الورق', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('تقليل زمن الرسوم المتحركة لوتيرة أسرع'),
                      value: _fastAnimations,
                      activeThumbColor: AppColors.gold,
                      onChanged: _setFastAnimations,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    SwitchListTile(
                      secondary: const Icon(Icons.exit_to_app_rounded, color: AppColors.gold),
                      title: const Text('تأكيد الخروج أثناء اللعب', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('إظهار رسالة تأكيد لتفادي الخروج بالخطأ'),
                      value: _confirmExit,
                      activeThumbColor: AppColors.gold,
                      onChanged: _setConfirmExit,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 5. عن التطبيق والدعم (About & Help)
              _buildSectionTitle(Icons.info_outline_rounded, 'حول اللعبة والمعلومات'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
                      title: const Text('شرح طريقة وقوانين كوت بو ٤'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                      onTap: () {
                        SoundService.instance.play(Sfx.click);
                        Navigator.push(context, appRoute<void>(const RulesPage()));
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.share_rounded, color: AppColors.gold),
                      title: const Text('شارك اللعبة مع أصحابك'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                      onTap: () {
                        SoundService.instance.play(Sfx.click);
                        Share.share('العب كوت بو ٤ - لعبة الورق الخليجية الممتعة أونلاين وضد البوتات!');
                      },
                    ),
                    if (AppConfig.privacyUrl.isNotEmpty) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.gold),
                        title: const Text('سياسة الخصوصية'),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white54),
                        onTap: () => launchUrl(
                          Uri.parse(AppConfig.privacyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.verified_rounded, color: AppColors.gold),
                      title: const Text('إصدار اللعبة'),
                      subtitle: Text('كوت بو ٤ • v${AppConfig.version}'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 6. منطقة الحساب والأمان (خروج / حذف)
              if (canDelete) ...[
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                    title: const Text(
                      'حذف الحساب نهائياً',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('حذف كل البيانات والإحصائيات نهائياً'),
                    onTap: () => _confirmDelete(context),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              GoldButton(
                label: 'تسجيل الخروج',
                icon: Icons.logout_rounded,
                outlined: true,
                onPressed: () {
                  SoundService.instance.play(Sfx.click);
                  context.read<AuthCubit>().signOut();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.goldLight),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white12,
    );
  }
}
