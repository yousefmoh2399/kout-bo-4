import 'package:flutter/material.dart';

import '../core/sound.dart';
import '../core/theme.dart';
import 'effects.dart';

/// خلفية "الجوخ" الخضراء المشتركة بين كل الشاشات.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child, this.animated = false});

  final Widget child;

  /// رموز الورق الطافية (للشاشات الهادئة فقط، لا للطاولة).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [Color(0xFF14804F), AppColors.feltDark],
        ),
      ),
      child: animated
          ? Stack(children: [const Positioned.fill(child: FloatingSuits()), child])
          : child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: child,
    );
  }
}

/// زر ذهبي رئيسي أو شفاف ثانوي.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final fg = outlined ? AppColors.gold : Colors.black87;
    final child = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          );
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled
              ? () {
                  SoundService.instance.play(Sfx.click);
                  onPressed!();
                }
              : null,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: outlined
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: outlined ? Border.all(color: AppColors.gold, width: 1.6) : null,
              boxShadow: outlined
                  ? null
                  : const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
