import 'package:flutter/material.dart';

import '../core/sound.dart';
import '../core/theme.dart';
import 'effects.dart';

/// خلفية "الجوخ الأخضر الفاخر" المستوحاة من كبرى صالات الألعاب.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child, this.animated = false});

  final Widget child;

  /// رموز الورق الطافية بأناقة في الخلفية
  final bool animated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.35,
          colors: [
            AppColors.feltVibrant,
            AppColors.felt,
            AppColors.feltDark,
            AppColors.feltDeep,
          ],
          stops: [0.0, 0.45, 0.85, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // تدرج إضاءة فينييت ناعم على الحواف
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(90),
                  ],
                ),
              ),
            ),
          ),
          if (animated) const Positioned.fill(child: FloatingSuits()),
          child,
        ],
      ),
    );
  }
}

/// بطاقة زجاجية فاخرة (Frosted Glass Card) مع إطار مضيء ناعم.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withAlpha(35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// زر ذهبي ملكي بارز مع تأثيرات حركية ولمسة فاخرة.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.busy = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool busy;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final fg = outlined ? AppColors.goldLight : const Color(0xFF1C1305);

    final childWidget = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ));

    return Opacity(
      opacity: enabled || busy ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled
              ? () {
                  SoundService.instance.play(Sfx.click);
                  SoundService.instance.tap();
                  onPressed!();
                }
              : null,
          child: Ink(
            padding: padding,
            decoration: BoxDecoration(
              gradient: outlined
                  ? null
                  : const LinearGradient(
                      colors: [
                        AppColors.goldLight,
                        AppColors.gold,
                        AppColors.goldDark,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                    ),
              color: outlined ? Colors.black.withAlpha(70) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: outlined ? AppColors.gold.withAlpha(200) : AppColors.goldLight.withAlpha(160),
                width: outlined ? 1.5 : 1.0,
              ),
              boxShadow: outlined
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(110),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: AppColors.gold.withAlpha(50),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
            ),
            child: Center(widthFactor: 1, child: childWidget),
          ),
        ),
      ),
    );
  }
}

/// شارة مذهبة أنيقة للمعلومات والحالات.
class GoldBadge extends StatelessWidget {
  const GoldBadge({
    super.key,
    required this.text,
    this.icon,
    this.color = AppColors.gold,
  });

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(160), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.feltDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.gold.withAlpha(140)),
        ),
      ),
    );
}

/// نافذة حوار فاخرة متوافقة مع الوضع الأفقي وتصميم الديوانية الملكي.
Future<T?> showLuxuryDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
  IconData? icon,
  Color accentColor = AppColors.gold,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withAlpha(165),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A2A1C), Color(0xFF04150E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor.withAlpha(185), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(180),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentColor.withAlpha(35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withAlpha(28),
                      border: Border.all(color: accentColor.withAlpha(150), width: 1.2),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.goldLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, accentColor.withAlpha(180), Colors.transparent],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                content,
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Flexible(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
