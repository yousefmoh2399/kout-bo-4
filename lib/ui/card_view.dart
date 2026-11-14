import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/card.dart';

class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    this.width = 56,
    this.dimmed = false,
    this.highlighted = false,
  });

  final PlayingCard card;
  final double width;
  final bool dimmed;
  final bool highlighted;

  double get height => width * 1.4;

  @override
  Widget build(BuildContext context) {
    final isRed = card.isJoker ? card.isRedJoker : card.suit!.isRed;
    final color = isRed ? AppColors.cardRed : Colors.black87;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFB9B2A0) : AppColors.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? Colors.amber : Colors.black26,
          width: highlighted ? 2.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: card.isJoker ? _joker(color) : _suited(color),
    );
  }

  Widget _joker(Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🃏', style: TextStyle(fontSize: width * 0.45)),
          Text(
            card.isRedJoker ? 'جيكر' : 'ميكر',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: width * 0.22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _suited(Color color) {
    return Stack(
      children: [
        Positioned(
          top: 3,
          left: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                card.rank!.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.3,
                  height: 1,
                ),
              ),
              Text(
                card.suit!.symbol,
                style: TextStyle(color: color, fontSize: width * 0.26, height: 1),
              ),
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: width * 0.2),
            child: Text(
              card.suit!.symbol,
              style: TextStyle(color: color, fontSize: width * 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class CardBackView extends StatelessWidget {
  const CardBackView({super.key, this.width = 30, this.label});

  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF7A1424),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: label == null
          ? null
          : Text(
              label!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: width * 0.45,
              ),
            ),
    );
  }
}
