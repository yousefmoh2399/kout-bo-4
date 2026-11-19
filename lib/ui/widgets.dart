import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
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
                        fontSize: 15.5,
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
                  fontSize: 15.5,
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

void showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: const Color(0xFF0F261C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? const Color(0xFFEF5350)
                : (isSuccess ? AppColors.gold : AppColors.gold.withAlpha(220)),
            width: 1.6,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.info_outline_rounded
                  : (isSuccess ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined),
              color: isError ? const Color(0xFFFF8A80) : AppColors.goldLight,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.tajawal(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// نافذة حوار فاخرة متوافقة بالكامل مع الوضعين الطولي والعرضي وتدعم الكيبورد بأمان.
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
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withAlpha(165),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) {
      final media = MediaQuery.of(ctx);
      final isLandscape = media.size.width > media.size.height;
      return SafeArea(
        child: AnimatedPadding(
          padding: media.viewInsets,
          duration: const Duration(milliseconds: 100),
          curve: Curves.decelerate,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLandscape ? 6 : 16,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isLandscape ? 440 : 400,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isLandscape ? 12 : 18,
                    20,
                    isLandscape ? 10 : 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2A1C), Color(0xFF04150E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withAlpha(185), width: 1.5),
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
                      if (icon != null && !isLandscape) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withAlpha(28),
                            border: Border.all(color: accentColor.withAlpha(150), width: 1.2),
                          ),
                          child: Icon(icon, color: accentColor, size: 20),
                        ),
                        const SizedBox(height: 8),
                      ] else if (icon != null && isLandscape) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: accentColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isLandscape) ...[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.goldLight,
                            height: 1.25,
                          ),
                        ),
                      ],
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
                      SizedBox(height: isLandscape ? 8 : 14),
                      content,
                      SizedBox(height: isLandscape ? 10 : 18),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: actions,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
