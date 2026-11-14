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
  int _tab = 0; // 0: الصوت، 1: أسلوب اللعب، 2: حول اللعبة

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
    final newName = await showLuxuryDialog<String>(
      context: context,
      title: 'تعديل اسم اللاعب',
      icon: Icons.badge_outlined,
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'الاسم الجديد',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
        GoldButton(
          label: 'حفظ',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
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
    final ok = await showLuxuryDialog<bool>(
      context: context,
      title: 'حذف الحساب نهائياً؟',
      icon: Icons.warning_amber_rounded,
      accentColor: AppColors.danger,
      content: const Text(
        'سيتم حذف حسابك وكل بياناتك المسجلة ولا يمكن التراجع عن هذا الإجراء.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
      ),
      actions: [
        GoldButton(
          label: 'إلغاء',
          outlined: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onPressed: () => Navigator.pop(context, false),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('نعم، احذف', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
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
      body: FeltBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. شريط العنوان العلوي المخصص
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          SoundService.instance.play(Sfx.click);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xC0041B12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withAlpha(100)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: AppColors.goldLight),
                              SizedBox(width: 4),
                              Text(
                                'رجوع',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'لوحة الإعدادات',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(80),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'v${AppConfig.version}',
                        style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. جسم الإعدادات (تصميم ثنائي اللوحات في الوضع الأفقي)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final profilePanel = _buildProfileSidebar(authState, canDelete);
                    final tabsPanel = _buildTabbedSettings(expandBody: isWide);

                    if (isWide) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 4, child: profilePanel),
                                const SizedBox(width: 18),
                                Expanded(flex: 6, child: tabsPanel),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          profilePanel,
                          const SizedBox(height: 16),
                          tabsPanel,
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

  Widget _buildProfileSidebar(AppAuthState authState, bool canDelete) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.gold.withAlpha(100),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ملف اللاعب
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    authState.name.isEmpty ? '?' : authState.name.characters.first,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1304),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authState.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _editName(context, authState.name),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_rounded, size: 16, color: AppColors.gold),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        authState.isGuest ? 'حساب ضيف (محلي)' : 'حساب مسجل بالبريد',
                        style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 12),

            // إحصائيات اللعب
            FutureBuilder<PlayerStats?>(
              future: _statsFuture,
              builder: (context, snap) {
                final st = snap.data;
                final games = st?.games ?? 0;
                final wins = st?.wins ?? 0;
                final losses = games - wins;
                final winRate = games == 0 ? 0 : ((wins / games) * 100).round();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statBox('المباريات', '$games', AppColors.goldLight)),
                        const SizedBox(width: 8),
                        Expanded(child: _statBox('الانتصارات', '$wins', const Color(0xFF48BB78))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _statBox('الهزائم', '$losses', const Color(0xFFFC8181))),
                        const SizedBox(width: 8),
                        Expanded(child: _statBox('نسبة الفوز', '$winRate%', AppColors.gold)),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 15, color: AppColors.gold),
                    label: const Text('السجل', style: TextStyle(color: AppColors.goldLight, fontSize: 11.5)),
                    onPressed: () {
                      SoundService.instance.play(Sfx.click);
                      showMatchHistorySheet(context);
                    },
                  ),
                ),
                Container(width: 1, height: 18, color: Colors.white12),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.emoji_events_rounded, size: 15, color: AppColors.gold),
                    label: const Text('المتصدرون', style: TextStyle(color: AppColors.goldLight, fontSize: 11.5)),
                    onPressed: () {
                      SoundService.instance.play(Sfx.click);
                      showLeaderboardSheet(context);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            GoldButton(
              label: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              outlined: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onPressed: () {
                SoundService.instance.play(Sfx.click);
                context.read<AuthCubit>().signOut();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
            if (canDelete) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.danger),
                label: const Text('حذف الحساب نهائياً', style: TextStyle(color: AppColors.danger, fontSize: 11.5)),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildTabbedSettings({required bool expandBody}) {
    final tabContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _tab == 0
          ? _buildAudioTab()
          : (_tab == 1 ? _buildGameplayTab() : _buildAboutTab()),
    );

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.gold.withAlpha(100),
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // تبويبات الإعدادات
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(90),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _tabBtn(0, Icons.volume_up_rounded, 'الصوت والاهتزاز'),
                _tabBtn(1, Icons.style_rounded, 'أسلوب اللعب'),
                _tabBtn(2, Icons.info_outline_rounded, 'حول اللعبة'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // محتوى التبويب المختار
          if (expandBody)
            Expanded(
              child: SingleChildScrollView(child: tabContent),
            )
          else
            tabContent,
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService.instance.play(Sfx.click);
          setState(() => _tab = idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [AppColors.goldLight, AppColors.gold])
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? const Color(0xFF1E1304) : Colors.white70,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: active ? const Color(0xFF1E1304) : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTab() {
    return Column(
      key: const ValueKey('tab_audio'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.enabled,
          builder: (context, on, _) => SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.music_note_rounded, color: AppColors.gold),
            title: const Text('المؤثرات الصوتية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: const Text('أصوات رمي الورق، التوزيع، والفوز', style: TextStyle(fontSize: 11)),
            value: on,
            activeThumbColor: AppColors.gold,
            onChanged: (val) {
              SoundService.instance.setEnabled(val);
              SoundService.instance.play(Sfx.click);
            },
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        ValueListenableBuilder<double>(
          valueListenable: SoundService.instance.volume,
          builder: (context, vol, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.turnAlert,
          builder: (context, alert, _) => SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.gold),
            title: const Text('تنبيه حلول دورك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: const Text('رنين ناعم عند بدء دورك باللعب', style: TextStyle(fontSize: 11)),
            value: alert,
            activeThumbColor: AppColors.gold,
            onChanged: (val) {
              SoundService.instance.setTurnAlert(val);
              SoundService.instance.play(Sfx.turn);
            },
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.haptics,
          builder: (context, on, _) => SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.vibration_rounded, color: AppColors.gold),
            title: const Text('الاهتزاز اللمسي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: const Text('نبضات لمسية خفيفة مع أفعال اللعب', style: TextStyle(fontSize: 11)),
            value: on,
            activeThumbColor: AppColors.gold,
            onChanged: (val) {
              SoundService.instance.setHaptics(val);
              if (val) SoundService.instance.impact();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameplayTab() {
    return Column(
      key: const ValueKey('tab_gameplay'),
      children: [
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.speed_rounded, color: AppColors.gold),
          title: const Text('تسريع حركات الورق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: const Text('تقليل زمن الرسوم المتحركة لوتيرة أسرع', style: TextStyle(fontSize: 11)),
          value: _fastAnimations,
          activeThumbColor: AppColors.gold,
          onChanged: _setFastAnimations,
        ),
        const Divider(height: 1, color: Colors.white12),
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.exit_to_app_rounded, color: AppColors.gold),
          title: const Text('تأكيد الخروج أثناء اللعب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: const Text('إظهار رسالة تأكيد لتفادي الخروج بالخطأ', style: TextStyle(fontSize: 11)),
          value: _confirmExit,
          activeThumbColor: AppColors.gold,
          onChanged: _setConfirmExit,
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return Column(
      key: const ValueKey('tab_about'),
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
          title: const Text('شرح طريقة وقوانين كوت بو ٤', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
          onTap: () {
            SoundService.instance.play(Sfx.click);
            Navigator.push(context, appRoute<void>(const RulesPage()));
          },
        ),
        const Divider(height: 1, color: Colors.white12),
        ListTile(
          dense: true,
          leading: const Icon(Icons.share_rounded, color: AppColors.gold),
          title: const Text('شارك اللعبة مع أصحابك', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
          onTap: () {
            SoundService.instance.play(Sfx.click);
            Share.share('العب كوت بو ٤ - لعبة الورق الخليجية الممتعة أونلاين وضد البوتات!');
          },
        ),
        if (AppConfig.privacyUrl.isNotEmpty) ...[
          const Divider(height: 1, color: Colors.white12),
          ListTile(
            dense: true,
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.gold),
            title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white54),
            onTap: () => launchUrl(
              Uri.parse(AppConfig.privacyUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        const Divider(height: 1, color: Colors.white12),
        ListTile(
          dense: true,
          leading: const Icon(Icons.verified_rounded, color: AppColors.gold),
          title: const Text('إصدار اللعبة', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: Text('كوت بو ٤ • v${AppConfig.version}', style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
