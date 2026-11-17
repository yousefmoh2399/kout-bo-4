import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bloc/auth_cubit.dart';
import '../../bloc/game_bloc.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../domain/rules.dart';
import '../card_view.dart';
import '../effects.dart';
import '../panels.dart';
import '../store_page.dart';
import '../suit_icon.dart';
import '../widgets.dart';

Future<void> showLastTrickDialog(BuildContext context, GameState state) async {
  SoundService.instance.play(Sfx.click);
  final plays = state.lastTrick;
  if (plays.isEmpty) return;
  final winner = state.lastTrickWinner;
  await showLuxuryDialog<void>(
    context: context,
    title: 'آخر أكلة',
    icon: Icons.history_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (winner != null) ...[
          Text(
            'أخذها: ${state.names[winner]}',
            style: const TextStyle(
              color: AppColors.goldLight,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final p in plays)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayingCardView(
                    card: p.card,
                    width: 50,
                    highlighted: p.player == winner,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.names[p.player],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          p.player == winner ? FontWeight.w800 : FontWeight.w600,
                      color: p.player == winner
                          ? AppColors.goldLight
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
    actions: [
      GoldButton(
        label: 'إغلاق',
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

/// شريط أزرار التحكم الاحترافي (بتصميم ثلاثي الأبعاد بارز على غرار الألعاب العالمية الكبرى).
class TopControlsPill extends StatelessWidget {
  const TopControlsPill({
    super.key,
    required this.state,
    required this.me,
    this.onResync,
    this.isPortrait = false,
    this.roomCode,
  });

  final GameState state;
  final int me;
  final VoidCallback? onResync;
  final bool isPortrait;
  final String? roomCode;

  Future<void> _showLastTrick(BuildContext context) =>
      showLastTrickDialog(context, state);

  Future<void> _confirmRestart(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final ok = await showLuxuryDialog<bool>(
      context: context,
      title: 'إعادة المباراة؟',
      icon: Icons.replay_rounded,
      content: const Text(
        'سيتم تصفير النقاط الحالية وبدء مباراة جديدة من البداية.',
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
        GoldButton(
          label: 'إعادة المباراة',
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true && context.mounted) {
      context.read<GameBloc>().add(const GameStarted());
    }
  }

  Future<void> _showExtendTimeDialog(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final authCubit = context.read<AuthCubit>();
    final userCoins = authCubit.state.coins;
    final isOnline = roomCode != null;
    int selectedMinutes = 20;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cost = (selectedMinutes ~/ 20) * 500;
          final canAfford = !isOnline || userCoins >= cost;

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF133B2B), Color(0xFF091E16), Color(0xFF04100C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border.all(color: AppColors.gold.withAlpha(160), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(220),
                  blurRadius: 32,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(140),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withAlpha(30),
                          border: Border.all(color: AppColors.gold, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppColors.goldLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تمديد وقت المباراة',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'زيادة مؤقت الغرفة ومواصلة اللعب الحماسي',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  if (isOnline) ...[
                    // رصيد اللاعب
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gold.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                'رصيدك الحالي: $userCoins نقطة',
                                style: TextStyle(
                                  color: canAfford ? AppColors.goldLight : AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'التكلفة: $cost نقطة',
                            style: const TextStyle(
                              color: Color(0xFF4BE0A8),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'اختر مدة التمديد:',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in [20, 40, 60])
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            SoundService.instance.tap();
                            setSheetState(() => selectedMinutes = m);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: selectedMinutes == m
                                  ? const LinearGradient(
                                      colors: [Color(0xFFF3D270), Color(0xFFD4AF37)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0x990C2219), Color(0x9905140F)],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMinutes == m ? AppColors.goldLight : Colors.white24,
                                width: selectedMinutes == m ? 1.4 : 0.9,
                              ),
                            ),
                            child: Text(
                              '+$m دقيقة (${isOnline ? '${(m ~/ 20) * 500} نقطة' : 'مجاناً'})',
                              style: TextStyle(
                                color: selectedMinutes == m ? const Color(0xFF1B1102) : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isOnline && !canAfford) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withAlpha(120)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'رصيدك لا يكفي ($userCoins نقطة). تحتاج $cost نقطة لتمديد الوقت.',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              StorePage.show(context, requiredPoints: cost);
                            },
                            child: const Text('اشحن الآن', style: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: GoldButton(
                          label: 'إلغاء',
                          outlined: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 7,
                        child: GoldButton(
                          label: !canAfford ? 'اشحن النقاط' : 'تأكيد التمديد',
                          icon: !canAfford ? Icons.monetization_on_rounded : Icons.check_circle_rounded,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: !canAfford
                              ? () {
                                  Navigator.pop(ctx);
                                  StorePage.show(context, requiredPoints: cost);
                                }
                              : () async {
                                  Navigator.pop(ctx);
                                  if (isOnline) {
                                    authCubit.setCoins(userCoins - cost);
                                    try {
                                      final client = Supabase.instance.client;
                                      await client.rpc('extend_room_time', params: {
                                        'p_room_code': roomCode,
                                        'p_minutes': selectedMinutes,
                                      });
                                    } catch (_) {
                                      try {
                                        final client = Supabase.instance.client;
                                        final uid = client.auth.currentUser?.id;
                                        if (uid != null) {
                                          await client.from('profiles').update({
                                            'coins': userCoins - cost,
                                          }).eq('id', uid);
                                        }
                                      } catch (_) {}
                                    }
                                  }
                                  if (context.mounted) {
                                    context.read<GameBloc>().add(MatchTimeExtended(additionalMinutes: selectedMinutes));
                                    SoundService.instance.play(Sfx.win);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم تمديد وقت المباراة بنجاح (+ $selectedMinutes دقيقة)! 🎉'),
                                        backgroundColor: const Color(0xFF1B6B46),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Future<void> _showMoreMenu(BuildContext context, {required bool canRestart}) async {
    SoundService.instance.play(Sfx.click);
    await showLuxuryDialog<void>(
      context: context,
      title: 'خيارات المباراة',
      icon: Icons.tune_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canRestart) ...[
            _MoreMenuTile(
              icon: Icons.replay_rounded,
              title: 'إعادة المباراة',
              subtitle: 'تصفير النقاط وبدء مباراة جديدة',
              color: const Color(0xFFE67E22),
              onTap: () {
                Navigator.pop(context);
                _confirmRestart(context);
              },
            ),
            const SizedBox(height: 8),
          ],
          if (state.matchEndsAt != null) ...[
            _MoreMenuTile(
              icon: Icons.hourglass_top_rounded,
              title: 'تمديد وقت المباراة',
              subtitle: 'تمديد مؤقت المباراة بمقدار ٢٠ دقيقة إضافية',
              color: const Color(0xFFF39C12),
              onTap: () {
                Navigator.pop(context);
                _showExtendTimeDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
          if (onResync != null) ...[
            _MoreMenuTile(
              icon: Icons.sync_rounded,
              title: 'مزامنة الاتصال',
              subtitle: 'إعادة تحديث بيانات الطاولة فوراً',
              color: const Color(0xFF1ABC9C),
              onTap: () {
                Navigator.pop(context);
                SoundService.instance.tap();
                onResync!();
              },
            ),
            const SizedBox(height: 8),
          ],
          if (state.lastTrick.isNotEmpty) ...[
            _MoreMenuTile(
              icon: Icons.history_rounded,
              title: 'آخر أكلة',
              subtitle: 'عرض الأوراق التي لُعبت في الأكلة السابقة',
              color: const Color(0xFF9B59B6),
              onTap: () {
                Navigator.pop(context);
                _showLastTrick(context);
              },
            ),
          ],
        ],
      ),
      actions: [
        GoldButton(
          label: 'إغلاق',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc>();
    final isAuto = state.autoSeats.contains(me);
    final canRestart = !bloc.remote && state.phase != GamePhase.idle;
    final btnSize = isPortrait ? 32.0 : 34.0;
    final spacing = isPortrait ? 5.0 : 6.0;
    final hasSecondary = canRestart || onResync != null || state.lastTrick.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. زر الخروج الاحترافي (لون ياقوتي فاخر بارز وواضح لا يختفي)
        _Studio3DButton(
          tooltip: 'خروج من الطاولة',
          icon: Icons.exit_to_app_rounded,
          size: btnSize,
          topColor: const Color(0xFFE74C3C),
          bottomColor: const Color(0xFFC0392B),
          lipColor: const Color(0xFF922B21),
          glowColor: const Color(0xFFE74C3C),
          onPressed: () {
            SoundService.instance.play(Sfx.click);
            Navigator.of(context).maybePop();
          },
        ),
        SizedBox(width: spacing),

        // 2. زر الصوت والمؤثرات ثلاثي الأبعاد
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.enabled,
          builder: (context, on, _) => _Studio3DButton(
            tooltip: on ? 'كتم الصوت' : 'تشغيل الصوت',
            icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: btnSize,
            topColor: on ? const Color(0xFF2ECC71) : const Color(0xFF566573),
            bottomColor: on ? const Color(0xFF1E8449) : const Color(0xFF2C3E50),
            lipColor: on ? const Color(0xFF145A32) : const Color(0xFF1B2631),
            onPressed: () {
              SoundService.instance.tap();
              SoundService.instance.setEnabled(!on);
            },
          ),
        ),
        SizedBox(width: spacing),

        // 3. زر البوت (اللعب التلقائي)
        _Studio3DButton(
          tooltip: isAuto ? 'إيقاف اللعب التلقائي' : 'تشغيل اللعب التلقائي',
          icon: Icons.smart_toy_rounded,
          size: btnSize,
          topColor: isAuto ? const Color(0xFFF39C12) : const Color(0xFF2E4053),
          bottomColor:
              isAuto ? const Color(0xFFD68910) : const Color(0xFF1C2833),
          lipColor: isAuto ? const Color(0xFF9A6008) : const Color(0xFF11171D),
          glowColor: isAuto ? AppColors.gold : null,
          onPressed: () {
            SoundService.instance.play(Sfx.click);
            bloc.add(AutoPlayToggled(enabled: !isAuto));
          },
        ),

        // في الوضع الرأسي: تجميع الخيارات الثانوية في زر خيارات أنيق لتوفير المساحة
        if (isPortrait && hasSecondary) ...[
          SizedBox(width: spacing),
          _Studio3DButton(
            tooltip: 'خيارات إضافية',
            icon: Icons.more_horiz_rounded,
            size: btnSize,
            topColor: const Color(0xFF4A5568),
            bottomColor: const Color(0xFF2D3748),
            lipColor: const Color(0xFF1A202C),
            onPressed: () => _showMoreMenu(context, canRestart: canRestart),
          ),
        ],

        // في الوضع الأفقي: عرض الأزرار الثانوية مباشرة لتوفر المساحة الكافية
        if (!isPortrait) ...[
          // 4. زر آخر أكلة
          if (state.lastTrick.isNotEmpty) ...[
            SizedBox(width: spacing),
            _Studio3DButton(
              tooltip: 'آخر أكلة',
              icon: Icons.history_rounded,
              size: btnSize,
              topColor: const Color(0xFF8E44AD),
              bottomColor: const Color(0xFF6C3483),
              lipColor: const Color(0xFF4A235A),
              onPressed: () => _showLastTrick(context),
            ),
          ],

          // 5. زر مزامنة الاتصال (للأونلاين)
          if (onResync != null) ...[
            SizedBox(width: spacing),
            _Studio3DButton(
              tooltip: 'مزامنة الاتصال',
              icon: Icons.sync_rounded,
              size: btnSize,
              topColor: const Color(0xFF1ABC9C),
              bottomColor: const Color(0xFF117864),
              lipColor: const Color(0xFF0B5345),
              onPressed: () {
                SoundService.instance.tap();
                onResync!();
              },
            ),
          ],

          // 6. زر إعادة المباراة (للعب الفردي/المضيف)
          if (canRestart) ...[
            SizedBox(width: spacing),
            _Studio3DButton(
              tooltip: 'إعادة المباراة',
              icon: Icons.replay_rounded,
              size: btnSize,
              topColor: const Color(0xFF34495E),
              bottomColor: const Color(0xFF212F3D),
              lipColor: const Color(0xFF151E27),
              onPressed: () => _confirmRestart(context),
            ),
          ],
        ],

        SizedBox(width: spacing),
        // كبسولة المؤقت الاحترافية (قابلة للنقر لتمديد الوقت)
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => _showExtendTimeDialog(context),
            child: Tooltip(
              message: 'اضغط لتمديد وقت المباراة',
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPortrait ? 7 : 9,
                  vertical: isPortrait ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xEE09291D), Color(0xEE03150E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.gold.withAlpha(120),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ElapsedClock(state: state, compact: isPortrait),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(120)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر ألعاب احترافي ثلاثي الأبعاد مع لمعة علوية وحافة سفلية وتأثير ضغط واقعي.
class _Studio3DButton extends StatefulWidget {
  const _Studio3DButton({
    required this.tooltip,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.lipColor,
    required this.onPressed,
    this.glowColor,
    this.size = 34.0,
  });

  final String tooltip;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color lipColor;
  final VoidCallback onPressed;
  final Color? glowColor;
  final double size;

  @override
  State<_Studio3DButton> createState() => _Studio3DButtonState();
}

class _Studio3DButtonState extends State<_Studio3DButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    final isz = sz * 0.51;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          width: sz,
          height: sz,
          padding: EdgeInsets.only(top: _pressed ? 2.5 : 0.0),
          child: Stack(
            children: [
              // الحافة السفلية الثلاثية الأبعاد (3D Lip)
              Positioned.fill(
                top: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.lipColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                      if (widget.glowColor != null)
                        BoxShadow(
                          color: widget.glowColor!.withAlpha(130),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                ),
              ),
              // وجه الزر العلوي اللامع
              Positioned.fill(
                bottom: _pressed ? 0.0 : 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.topColor, widget.bottomColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(140),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // لمعة زجاجية علوية (Specular Highlight)
                      Positioned(
                        top: 1.5,
                        left: 3,
                        right: 3,
                        height: sz * 0.28,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withAlpha(85),
                                Colors.white.withAlpha(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        widget.icon,
                        size: isz,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة النتائج واللزمة الاحترافية (على طراز الاستوديوهات العالمية).
class ScoreAndContractHud extends StatelessWidget {
  const ScoreAndContractHud({
    super.key,
    required this.state,
    required this.me,
    this.compact = false,
  });

  final GameState state;
  final int me;
  final bool compact;

  Future<void> _showRoundHistory(BuildContext context) async {
    SoundService.instance.play(Sfx.click);
    final lt = Rules.teamOf(me);
    final history = state.roundHistory;
    await showLuxuryDialog<void>(
      context: context,
      title: 'تفاصيل الجولات',
      icon: Icons.receipt_long_rounded,
      content: history.isEmpty
          ? const Text(
              'لم تنتهِ أي جولة بعد في هذه المباراة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < history.length; i++)
                      _RoundHistoryRow(
                        roundNumber: i + 1,
                        result: history[i],
                        localTeam: lt,
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        GoldButton(
          label: 'إغلاق',
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final lt = Rules.teamOf(me);
    final inContract = s.bidder != null &&
        (s.phase == GamePhase.chooseTrump ||
            s.phase == GamePhase.playing ||
            s.phase == GamePhase.roundOver ||
            s.phase == GamePhase.gameOver);
    final showTricks = s.phase == GamePhase.playing ||
        s.phase == GamePhase.roundOver ||
        s.phase == GamePhase.gameOver;

    return GestureDetector(
      onTap: () => _showRoundHistory(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // الشريط الرئيسي للنقاط (فريقنا مقابل الخصم)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 6,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xF6092C1F), Color(0xF603150E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.gold.withAlpha(155),
                width: 1.2,
              ),
              boxShadow: [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.gold.withAlpha(45),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _teamCapsule(
                  label: 'لنا',
                  score: s.scores[lt],
                  tricks: showTricks ? s.tricksWon[lt] : null,
                  bgColor: const Color(0xFF11382B),
                  borderColor: const Color(0xFF2ECC71),
                  textColor: const Color(0xFF58F29A),
                  compact: compact,
                ),
                SizedBox(width: compact ? 4 : 6),
                _teamCapsule(
                  label: 'لهم',
                  score: s.scores[1 - lt],
                  tricks: showTricks ? s.tricksWon[1 - lt] : null,
                  bgColor: const Color(0xFF3B161A),
                  borderColor: const Color(0xFFE74C3C),
                  textColor: const Color(0xFFFF8A7A),
                  compact: compact,
                ),
              ],
            ),
          ),

          // شريط العقد/الهدف السفلي المذهب (مثل شريط النقاط في الصورة المرجعية)
          Transform.translate(
            offset: const Offset(0, -2),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 10,
                vertical: compact ? 1.5 : 2,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C2008), Color(0xFF1A1204)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
                border: Border.all(
                  color: AppColors.gold.withAlpha(140),
                  width: 0.9,
                ),
              ),
              child: inContract
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'طلب ${s.highestBid}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 9 : 10,
                            color: AppColors.goldLight,
                          ),
                        ),
                        if (s.trump != null) ...[
                          SizedBox(width: compact ? 3 : 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SuitIcon(
                              suit: s.trump!,
                              size: compact ? 9.5 : 11,
                              color: s.trump!.isRed
                                  ? AppColors.cardRed
                                  : AppColors.cardBlack,
                            ),
                          ),
                        ],
                        SizedBox(width: compact ? 3 : 5),
                        Text(
                          '• ج ${s.roundNumber}',
                          style: TextStyle(
                            fontSize: compact ? 8.5 : 9.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'الهدف ${s.targetScore} • جولة ${s.roundNumber}',
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldLight,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamCapsule({
    required String label,
    required int score,
    required int? tricks,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.5 : 9,
        vertical: compact ? 2.5 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor.withAlpha(140), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
          AnimatedNumber(
            value: score,
            style: TextStyle(
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w900,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (tricks != null) ...[
            SizedBox(width: compact ? 3.5 : 5),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 3.5 : 4.5,
                vertical: 0.5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(110),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$tricks',
                style: TextStyle(
                  fontSize: compact ? 8.5 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// شريط أعلى الطاولة الموحد والمتجاوب (GameTopBar).
/// يجمع أزرار التحكم ولوحة النقاط في صف أفقي واحد متناسق
/// لمنع أي تداخل أو حجب لزر الخروج أو النقاط على جميع أحجام الشاشات.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.state,
    required this.me,
    this.onResync,
    required this.isPortrait,
    this.roomCode,
  });

  final GameState state;
  final int me;
  final VoidCallback? onResync;
  final bool isPortrait;
  final String? roomCode;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. أزرار التحكم على اليسار (زر الخروج مثبت دوماً في أقصى اليسار)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TopControlsPill(
                  state: state,
                  me: me,
                  onResync: onResync,
                  isPortrait: isPortrait,
                  roomCode: roomCode,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. لوحة النقاط والعقد على اليمين (باتجاه RTL العربي الطبيعي)
          Directionality(
            textDirection: TextDirection.rtl,
            child: ScoreAndContractHud(
              state: state,
              me: me,
              compact: isPortrait,
            ),
          ),
        ],
      ),
    );
  }
}

/// مؤشر حي لحالة الدور والمرحلة الحالية.
class PhaseStatusTicker extends StatelessWidget {
  const PhaseStatusTicker({
    super.key,
    required this.state,
    required this.me,
    this.compact = false,
  });

  final GameState state;
  final int me;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actor = state.actor;
    if (actor == null ||
        state.phase == GamePhase.idle ||
        state.trick.isComplete) {
      return const SizedBox.shrink();
    }
    final isMe = actor == me && !state.autoSeats.contains(me);
    final actorName = state.names[actor];

    String text;
    if (state.phase == GamePhase.bidding) {
      text = isMe ? 'دورك للمزايدة' : 'المزايدة: $actorName';
    } else if (state.phase == GamePhase.chooseTrump) {
      text = isMe ? 'اختر لون الحكم' : '$actorName يختار الحكم';
    } else {
      text = isMe
          ? (compact ? 'دورك الآن' : 'دورك الآن — العب ورقة')
          : (compact ? 'دور $actorName' : 'الدور عند $actorName');
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: ConstrainedBox(
        key: ValueKey('$text|$compact'),
        constraints: BoxConstraints(maxWidth: compact ? 84 : 260),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 4 : 3.5,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppColors.gold.withAlpha(240) : const Color(0xEE08261B),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(
              color: isMe
                  ? Colors.white.withAlpha(210)
                  : AppColors.gold.withAlpha(100),
              width: 1.1,
            ),
            boxShadow: [
              if (isMe)
                BoxShadow(color: AppColors.gold.withAlpha(110), blurRadius: 10),
              const BoxShadow(color: Colors.black45, blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMe) ...[
                Icon(
                  Icons.touch_app_rounded,
                  size: compact ? 12 : 13,
                  color: const Color(0xFF1E1304),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: isMe
                        ? const Color(0xFF1E1304)
                        : Colors.white.withAlpha(230),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AutoPlayBanner extends StatelessWidget {
  const AutoPlayBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, c) => Transform.scale(scale: t, child: c),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 14 : 24),
          onTap: () {
            SoundService.instance.play(Sfx.click);
            context.read<GameBloc>().add(const AutoPlayToggled(enabled: false));
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 86 : 300),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 12,
                vertical: compact ? 4.5 : 3.5,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xEE183F2D), Color(0xEE081E14)],
                ),
                borderRadius: BorderRadius.circular(compact ? 14 : 24),
                border: Border.all(color: AppColors.gold, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(color: AppColors.gold.withAlpha(55), blurRadius: 8),
                ],
              ),
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smart_toy_rounded,
                                size: 12,
                                color: AppColors.goldLight,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'البوت شغال',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.goldLight, AppColors.gold],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'إيقاف البوت',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1304),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.smart_toy_rounded,
                            size: 14,
                            color: AppColors.goldLight,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'البوت يلعب عنك',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.goldLight, AppColors.gold],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'إيقاف واللعب بنفسي',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1304),
                              ),
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

class EmoteButton extends StatelessWidget {
  const EmoteButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Studio3DButton(
      tooltip: 'الدردشة السريعة',
      icon: Icons.chat_bubble_rounded,
      topColor: const Color(0xFFE67E22),
      bottomColor: const Color(0xFFD35400),
      lipColor: const Color(0xFF873600),
      onPressed: () {
        SoundService.instance.play(Sfx.click);
        onTap();
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0).toDouble(), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// ساعة مدة اللعبة (تتجمد عند نهايتها).
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({
    super.key,
    required this.state,
    this.compact = false,
  });

  final GameState state;
  final bool compact;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.state.endedAt == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.state.startedAt;
    final matchEnd = widget.state.matchEndsAt;
    Duration? remaining;
    var urgent = false;
    if (matchEnd != null) {
      final diff = matchEnd.difference(widget.state.endedAt ?? DateTime.now());
      remaining = diff.isNegative ? Duration.zero : diff;
      urgent = remaining.inSeconds <= 30;
    }

    final color = urgent ? AppColors.danger : AppColors.goldLight;
    final label = remaining != null
        ? formatDuration(remaining)
        : (started == null ? '00:00' : formatDuration(widget.state.elapsed));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          remaining != null
              ? Icons.hourglass_bottom_rounded
              : Icons.timer_outlined,
          size: widget.compact ? 12 : 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: widget.compact ? 10.5 : 11.5,
            fontWeight: FontWeight.w900,
            color: urgent ? AppColors.danger : Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (remaining != null) ...[
          const SizedBox(width: 3),
          Icon(
            Icons.add_circle_outline_rounded,
            size: widget.compact ? 10 : 12,
            color: AppColors.goldLight.withAlpha(200),
          ),
        ],
      ],
    );
  }
}

class _RoundHistoryRow extends StatelessWidget {
  const _RoundHistoryRow({
    required this.roundNumber,
    required this.result,
    required this.localTeam,
  });

  final int roundNumber;
  final RoundResult result;
  final int localTeam;

  @override
  Widget build(BuildContext context) {
    final bidderIsUs = result.bidderTeam == localTeam;
    final bidderLabel = bidderIsUs ? 'فريقنا' : 'الخصم';
    final bidLabel =
        result.forced ? 'ملزوم (${result.bid})' : 'طلب ${result.bid}';
    final statusLabel = result.success ? 'نجح' : 'انكسر';
    final usScored = result.scoringTeam == localTeam;
    final ptsColor =
        usScored ? const Color(0xFF4BE0A8) : const Color(0xFFFF7A6B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.gold.withAlpha(35),
            child: Text(
              '$roundNumber',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.goldLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$bidderLabel • $bidLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: result.success
                        ? const Color(0xFF4BE0A8)
                        : Colors.amberAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${result.points} ${usScored ? "لنا" : "لهم"}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ptsColor,
            ),
          ),
        ],
      ),
    );
  }
}
