import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import 'store_page.dart';
import 'widgets.dart';

/// يفتح نافذة إعدادات الطاولة أو إنشاء ديوانية بتصميم ديوانية ملكي متناسق.
/// يرجع [GameSettings] عند التأكيد، أو null عند الإلغاء أو الإغلاق.
Future<GameSettings?> showGameSettingsSheet(
  BuildContext context, {
  required String confirmLabel,
  bool isOnlineRoom = false,
  int userCoins = 0,
}) {
  return showModalBottomSheet<GameSettings>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: true,
    builder: (_) => _SettingsSheet(
      confirmLabel: confirmLabel,
      isOnlineRoom: isOnlineRoom,
      userCoins: userCoins,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.confirmLabel,
    this.isOnlineRoom = false,
    this.userCoins = 0,
  });

  final String confirmLabel;
  final bool isOnlineRoom;
  final int userCoins;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  var _settings = const GameSettings();
  bool _customTurn = false;
  bool _customMatch = false;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetH = MediaQuery.of(context).size.height * 0.88;
    final hasEnoughCoins =
        !widget.isOnlineRoom || widget.userCoins >= _settings.stakePoints;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetH),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF133B2B),
            Color(0xFF091E16),
            Color(0xFF04100C),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.gold.withAlpha(160), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(220),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: AppColors.gold.withAlpha(45),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. مقبض السحب العلوي الفاخر
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(140),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // 2. شريط العنوان الملكي مع زر الإغلاق (X) الصريح
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28543E), Color(0xFF0E2E20)],
                      ),
                      border: Border.all(color: AppColors.gold, width: 1.2),
                    ),
                    child: Icon(
                      widget.isOnlineRoom
                          ? Icons.add_home_work_rounded
                          : Icons.tune_rounded,
                      color: AppColors.goldLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isOnlineRoom
                              ? 'إنشاء ديوانية جديدة'
                              : 'إعدادات الطاولة',
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.isOnlineRoom
                              ? 'اضبط شروط وقوانين الغرفة للعب مع الربع'
                              : 'اختر أهداف وقواعد الجولة الفردية ضد البوتات',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // زر الإغلاق المذهب الواضح (X)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        SoundService.instance.play(Sfx.click);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(90),
                          border: Border.all(
                            color: AppColors.gold.withAlpha(120),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.goldLight,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1, thickness: 1),

            // 3. المحتوى القابل للتمرير
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // أ. نقاط الرهان (للغرف الأونلاين فقط)
                    if (widget.isOnlineRoom) ...[
                      _sectionCard(
                        icon: Icons.monetization_on_rounded,
                        title: 'نقاط الدخول والرهان',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final v in const [
                                  0,
                                  100,
                                  250,
                                  500,
                                  1000,
                                  2500,
                                  5000
                                ])
                                  _luxuryChip(
                                    label: v == 0 ? 'ودية (مجانية)' : '$v نقطة',
                                    selected: _settings.stakePoints == v,
                                    onTap: () => setState(
                                      () => _settings =
                                          _settings.copyWith(stakePoints: v),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // شريط تفاصيل الرصيد والجائزة
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(70),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gold.withAlpha(70),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 15,
                                        color: AppColors.goldLight,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'رصيدك: ${widget.userCoins} نقطة',
                                        style: TextStyle(
                                          color: hasEnoughCoins
                                              ? AppColors.goldLight
                                              : AppColors.danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_settings.stakePoints > 0)
                                    Row(
                                      children: [
                                        const Text(
                                          '🏆 الجائزة: ',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          '${(_settings.stakePoints * 4 * 0.95).toInt()} نقطة',
                                          style: const TextStyle(
                                            color: Color(0xFF4BE0A8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            // تحذير نقص الرصيد
                            if (!hasEnoughCoins) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withAlpha(40),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.danger.withAlpha(120),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.danger,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'رصيدك غير كافٍ لهذا الرهان.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        StorePage.show(
                                          context,
                                          requiredPoints: _settings.stakePoints,
                                        );
                                      },
                                      child: const Text(
                                        'اشحن الآن',
                                        style: TextStyle(
                                          color: AppColors.goldLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // ب. هدف المباراة (51 أو 101)
                    _sectionCard(
                      icon: Icons.flag_rounded,
                      title: 'هدف الفوز بالمباراة',
                      child: Row(
                        children: [
                          Expanded(
                            child: _scoreTargetCard(
                              title: '٥١ نقطة',
                              subtitle: 'لعبة سريعة وحماسية',
                              badge: 'سريعة',
                              selected: _settings.targetScore == 51,
                              onTap: () => setState(
                                () => _settings =
                                    _settings.copyWith(targetScore: 51),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _scoreTargetCard(
                              title: '١٠١ نقطة',
                              subtitle: 'كلاسيكية الديوانية الكاملة',
                              badge: 'الأصلية',
                              selected: _settings.targetScore == 101,
                              onTap: () => setState(
                                () => _settings =
                                    _settings.copyWith(targetScore: 101),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ج. مهلة الدور لكل لاعب
                    _sectionCard(
                      icon: Icons.timer_outlined,
                      title: 'مهلة الدور لكل لاعب',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final v in const [0, 15, 20, 30, -1])
                                _luxuryChip(
                                  label: v == -1
                                      ? 'مخصص...'
                                      : (v == 0 ? 'بدون مؤقت' : '$v ثانية'),
                                  selected: _customTurn
                                      ? v == -1
                                      : _settings.turnSeconds == v,
                                  onTap: () => setState(() {
                                    if (v == -1) {
                                      _customTurn = true;
                                      if (_settings.turnSeconds == 0) {
                                        _settings = _settings.copyWith(
                                          turnSeconds: 25,
                                        );
                                      }
                                    } else {
                                      _customTurn = false;
                                      _settings = _settings.copyWith(
                                        turnSeconds: v,
                                      );
                                    }
                                  }),
                                ),
                            ],
                          ),
                          if (_customTurn) ...[
                            const SizedBox(height: 8),
                            _stepper(
                              value: _settings.turnSeconds == 0
                                  ? 25
                                  : _settings.turnSeconds,
                              minVal: 5,
                              maxVal: 90,
                              step: 5,
                              unit: 'ثانية',
                              onChanged: (v) => setState(
                                () => _settings =
                                    _settings.copyWith(turnSeconds: v),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // د. مدة المباراة الإجمالية
                    _sectionCard(
                      icon: Icons.hourglass_bottom_rounded,
                      title: 'مدة المباراة الإجمالية',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final v in const [0, 5, 10, 15, -1])
                                _luxuryChip(
                                  label: v == -1
                                      ? 'مخصص...'
                                      : (v == 0
                                          ? 'مفتوح (بدون حد)'
                                          : (v <= 10
                                              ? '$v دقائق'
                                              : '$v دقيقة')),
                                  selected: _customMatch
                                      ? v == -1
                                      : _settings.matchMinutes == v,
                                  onTap: () => setState(() {
                                    if (v == -1) {
                                      _customMatch = true;
                                      if (_settings.matchMinutes == 0) {
                                        _settings = _settings.copyWith(
                                          matchMinutes: 7,
                                        );
                                      }
                                    } else {
                                      _customMatch = false;
                                      _settings = _settings.copyWith(
                                        matchMinutes: v,
                                      );
                                    }
                                  }),
                                ),
                            ],
                          ),
                          if (_customMatch) ...[
                            const SizedBox(height: 8),
                            _stepper(
                              value: _settings.matchMinutes == 0
                                  ? 7
                                  : _settings.matchMinutes,
                              minVal: 1,
                              maxVal: 120,
                              step: 1,
                              unit: 'دقيقة',
                              onChanged: (v) => setState(
                                () => _settings =
                                    _settings.copyWith(matchMinutes: v),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // هـ. مستوى ذكاء البوتات
                    _sectionCard(
                      icon: Icons.smart_toy_outlined,
                      title: 'مستوى ذكاء البوتات (عند غياب لاعب)',
                      child: Row(
                        children: [
                          Expanded(
                            child: _botDifficultyCard(
                              title: 'عادي',
                              desc: 'لعب ديوانية متوازن وممتع',
                              icon: Icons.sentiment_satisfied_alt_rounded,
                              selected: _settings.botDifficulty ==
                                  BotDifficulty.normal,
                              onTap: () => setState(
                                () => _settings = _settings.copyWith(
                                  botDifficulty: BotDifficulty.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _botDifficultyCard(
                              title: 'محترف 👑',
                              desc: 'تكتيك ذكي وقراءة للورق',
                              icon: Icons.military_tech_rounded,
                              selected:
                                  _settings.botDifficulty == BotDifficulty.pro,
                              onTap: () => setState(
                                () => _settings = _settings.copyWith(
                                  botDifficulty: BotDifficulty.pro,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Colors.white12, height: 1, thickness: 1),

            // 4. شريط الأزرار السفلي (إلغاء + تأكيد / بدء)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  // زر إلغاء صريح
                  Expanded(
                    flex: 4,
                    child: GoldButton(
                      label: 'إلغاء',
                      outlined: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        SoundService.instance.play(Sfx.click);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر التأكيد والبدء
                  Expanded(
                    flex: 7,
                    child: GoldButton(
                      label: !hasEnoughCoins
                          ? 'اشحن النقاط'
                          : widget.confirmLabel,
                      icon: !hasEnoughCoins
                          ? Icons.monetization_on_rounded
                          : (widget.isOnlineRoom
                              ? Icons.add_home_work_rounded
                              : Icons.play_arrow_rounded),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: !hasEnoughCoins
                          ? () {
                              Navigator.pop(context);
                              StorePage.show(
                                context,
                                requiredPoints: _settings.stakePoints,
                              );
                            }
                          : () {
                              SoundService.instance.play(Sfx.click);
                              Navigator.pop(context, _settings);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة قسم مؤطر بتصميم زجاجي مذهب
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC09241B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withAlpha(75), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.goldLight),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  /// زر اختيار شريحة مذهب أنيق
  Widget _luxuryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          SoundService.instance.play(Sfx.click);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFF3D270),
                      Color(0xFFD4AF37),
                      Color(0xFFA67C1E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0x990C2219), Color(0x9905140F)],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.goldLight : Colors.white24,
              width: selected ? 1.4 : 0.9,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(90),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1B1102) : Colors.white,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// بطاقة اختيار هدف المباراة (51 أو 101)
  Widget _scoreTargetCard({
    required String title,
    required String subtitle,
    required String badge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          SoundService.instance.play(Sfx.click);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xEE2A4736), Color(0xEE142E22)],
                  )
                : const LinearGradient(
                    colors: [Color(0x88071812), Color(0x88030C09)],
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white12,
              width: selected ? 1.5 : 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(50),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? AppColors.goldLight : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.gold.withAlpha(40)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? AppColors.gold.withAlpha(140)
                            : Colors.white12,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: selected ? AppColors.goldLight : Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.white38,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة مستوى ذكاء البوت
  Widget _botDifficultyCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          SoundService.instance.play(Sfx.click);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xEE2A4736), Color(0xEE142E22)],
                  )
                : const LinearGradient(
                    colors: [Color(0x88071812), Color(0x88030C09)],
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white12,
              width: selected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.goldLight : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? AppColors.goldLight : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white70 : Colors.white38,
                        fontSize: 10,
                      ),
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

  /// عداد تغيير القيم المخصصة
  Widget _stepper({
    required int value,
    required int minVal,
    required int maxVal,
    required int step,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > minVal
                ? () => onChanged((value - step).clamp(minVal, maxVal))
                : null,
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: AppColors.goldLight,
              size: 20,
            ),
          ),
          Text(
            '$value $unit',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.goldLight,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < maxVal
                ? () => onChanged((value + step).clamp(minVal, maxVal))
                : null,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.goldLight,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
