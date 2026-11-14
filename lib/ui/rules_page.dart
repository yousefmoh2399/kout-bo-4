import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets.dart';

class _Section {
  const _Section(this.icon, this.title, this.lines);
  final IconData icon;
  final String title;
  final List<String> lines;
}

const _sections = [
  _Section(Icons.groups_rounded, 'الفرق والأوراق', [
    'فريقان، كل فريق لاعبان متقابلان، واللعب بعكس عقارب الساعة.',
    'الأوراق من 6 إلى A (بدون ورقتي الـ 6 الحمراء) + الجيكر + الميكر = 36 ورقة، لكل لاعب 9.',
    'الترتيب من الأقوى: الجيكر ← A الحكم ← الميكر ← باقي الحكم ← بقية الأنواع.',
  ]),
  _Section(Icons.gavel_rounded, 'المزايدة', [
    'تبدأ على يمين الموزع. كل لاعب يعلن عدد اللمات (من 5 إلى 9) أو "طاف".',
    'يجب أن تتجاوز المزايدة السابقة. المزايدة بـ 9 تنهي المزايدة فوراً.',
    'لو مرّر الجميع، يُجبر الموزع على 5 ("ملزوم").',
    'الفائز بالمزايدة يختار الحكم ويبدأ اللعب.',
  ]),
  _Section(Icons.style_rounded, 'طريقة اللعب', [
    'يجب اتباع نوع الورقة الأولى. إن لم تملكه يمكنك رمي ورقة حكم أو أي ورقة.',
    'الأعلى يفوز باللمة ويبدأ اللمة التالية. ورقة الحكم تغلب أي ورقة أخرى.',
    'الجيكر والميكر يُلعبان في أي وقت، حتى لو معك نوع اللمة.',
  ]),
  _Section(Icons.bolt_rounded, 'بدء اللمة بالجيكر/الميكر', [
    'مسموح فقط إذا خرجت J وQ وK وA من الحكم في لمّات سابقة.',
    'أو إذا فريقك زايد بـ 9 (الاثنان مسموحان) أو بـ 8 (الجيكر فقط).',
    'لو كانت ورقتك الأخيرة تُرمى اضطراراً وتصبح بلا مرتبة، ونوع الورقة التالية يحدد نوع اللمة.',
  ]),
  _Section(Icons.scoreboard_rounded, 'حساب النقاط', [
    'نجح الفريق المزايد: يحصل على عدد اللمات التي طلبها. وبـ 9 ناجحة: 36 نقطة.',
    'فشل: يحصل الخصم على ضعف عدد المزايدة. و"ملزوم" الفاشل: 5 فقط للخصم.',
    'تنتهي الجولة فور تحقق المزايدة أو استحالتها.',
  ]),
  _Section(Icons.emoji_events_rounded, 'نهاية اللعبة', [
    'أول فريق يصل إلى الهدف (51 أو 101 نقطة).',
    'أو يصل إلى نصف الهدف تقريباً والخصم صفر.',
    'أو "باون" (9) ناجحة في الجولة الأولى.',
  ]),
];

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طريقة اللعب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: FeltBackground(
        child: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final s = _sections[i];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + i * 90),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
                ),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s.icon, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(s.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final line in s.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ', style: TextStyle(color: AppColors.gold)),
                              Expanded(child: Text(line, style: const TextStyle(height: 1.5))),
                            ],
                          ),
                        ),
                    ],
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
