import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/card.dart';
import 'suit_icon.dart';

/// انتقال شاشات ناعم (تلاشي + انزلاق خفيف).
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// رقم يعدّ تصاعدياً/تنازلياً بسلاسة عند تغيّره.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: value, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v', style: style),
    );
  }
}

/// رموز الورق باهتة تطفو ببطء في الخلفية.
class FloatingSuits extends StatefulWidget {
  const FloatingSuits({super.key});

  @override
  State<FloatingSuits> createState() => _FloatingSuitsState();
}

class _FloatingSuitsState extends State<FloatingSuits> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  late final List<_Glyph> _glyphs = _makeGlyphs();

  List<_Glyph> _makeGlyphs() {
    final r = Random(11);
    const suits = Suit.values;
    return List.generate(
      16,
      (i) => _Glyph(
        suit: suits[i % suits.length],
        x: r.nextDouble(),
        phase: r.nextDouble(),
        size: 28 + r.nextDouble() * 46,
        speed: 0.6 + r.nextDouble() * 0.8,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _SuitsPainter(_glyphs, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Glyph {
  const _Glyph({
    required this.suit,
    required this.x,
    required this.phase,
    required this.size,
    required this.speed,
  });
  final Suit suit;
  final double x;
  final double phase;
  final double size;
  final double speed;
}

class _SuitsPainter extends CustomPainter {
  _SuitsPainter(this.glyphs, this.t);

  final List<_Glyph> glyphs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(14)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final g in glyphs) {
      final progress = (t * g.speed + g.phase) % 1.0;
      final y = size.height * (1.1 - progress * 1.3);
      final x = size.width * g.x + sin((progress + g.phase) * 2 * pi) * 14;
      final path = SuitPath.getPath(g.suit, Size(g.size, g.size));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(sin(progress * 2 * pi) * 0.3);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SuitsPainter old) => old.t != t;
}

/// كونفيتي احتفالي عند الفوز.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();
  late final List<_Piece> _pieces = _make();

  List<_Piece> _make() {
    final r = Random();
    const colors = [AppColors.gold, Color(0xFFE05A4F), Colors.white, Color(0xFF4FC3A1), Color(0xFF6FA8FF)];
    return List.generate(
      70,
      (i) => _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        drift: (r.nextDouble() - 0.5) * 0.3,
        spin: r.nextDouble() * 8,
        size: 6 + r.nextDouble() * 7,
        color: colors[r.nextInt(colors.length)],
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
  });
  final double x;
  final double delay;
  final double drift;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(local);
      final x = size.width * (p.x + p.drift * local);
      final paint = Paint()..color = p.color.withAlpha((255 * (1 - local * 0.4)).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
