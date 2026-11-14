import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/auth_cubit.dart';
import '../core/config.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.feltDark,
        title: const Text('حذف الحساب نهائياً؟'),
        content: const Text('سيتم حذف حسابك وكل إحصائياتك ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('احذف'),
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
    final canDelete = auth.online && auth.state.userId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: FeltBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundService.instance.enabled,
                      builder: (context, on, _) => SwitchListTile(
                        secondary: const Icon(Icons.volume_up_rounded),
                        title: const Text('المؤثرات الصوتية'),
                        value: on,
                        onChanged: SoundService.instance.setEnabled,
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundService.instance.haptics,
                      builder: (context, on, _) => SwitchListTile(
                        secondary: const Icon(Icons.vibration_rounded),
                        title: const Text('الاهتزاز'),
                        value: on,
                        onChanged: SoundService.instance.setHaptics,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (AppConfig.privacyUrl.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('سياسة الخصوصية'),
                        onTap: () => launchUrl(
                          Uri.parse(AppConfig.privacyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    if (canDelete)
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                        title: const Text('حذف الحساب', style: TextStyle(color: AppColors.danger)),
                        onTap: () => _confirmDelete(context),
                      ),
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('كوت بو ٤'),
                      subtitle: Text('الإصدار ${AppConfig.version}'),
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
