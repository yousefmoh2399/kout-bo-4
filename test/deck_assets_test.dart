import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/core/card_image_service.dart';
import 'package:test_build_game/domain/card.dart';
import 'package:test_build_game/domain/deck.dart';
import 'package:test_build_game/ui/card_view.dart';

void main() {
  group('Deck Assets & Cards Verification', () {
    test('Deck has exactly 36 cards (Kuwaiti Kout Bo 4 rules)', () {
      final deck = Deck.build();
      expect(deck.length, 36);

      // Verify no red sixes
      for (final card in deck) {
        if (card.rank == Rank.six) {
          expect(card.suit == Suit.spades || card.suit == Suit.clubs, isTrue);
        }
      }

      // Verify jokers
      final jokers = deck.where((c) => c.isJoker).toList();
      expect(jokers.length, 2);
      expect(jokers.any((j) => j.isRedJoker), isTrue);
      expect(jokers.any((j) => !j.isRedJoker), isTrue);
    });

    test('All 37 assets (36 cards + 1 back) exist on disk and are valid PNGs', () {
      final assets = CardImageService.allCardAssets;
      expect(assets.length, 37);

      for (final assetPath in assets) {
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: '$assetPath must exist on disk');

        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(10000), reason: '$assetPath should be a high quality asset');

        // PNG signature: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
        expect(bytes[0], 0x89);
        expect(bytes[1], 0x50); // P
        expect(bytes[2], 0x4E); // N
        expect(bytes[3], 0x47); // G
      }
    });

    test('assetPath mappings for all cards follow consistent naming scheme', () {
      final deck = Deck.build();
      for (final card in deck) {
        final path = card.assetPath;
        expect(path.startsWith('assets/cards/'), isTrue);
        expect(path.endsWith('.png'), isTrue);

        if (card.isJoker) {
          if (card.isRedJoker) {
            expect(path, 'assets/cards/joker_red.png');
          } else {
            expect(path, 'assets/cards/joker_black.png');
          }
        } else {
          expect(path, 'assets/cards/${card.suit!.name}_${card.rank!.label}.png');
        }
      }
    });

    testWidgets('PlayingCardView renders all 36 cards without crashing or overflow', (tester) async {
      final deck = Deck.build();
      for (final card in deck) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PlayingCardView(
                  card: card,
                  width: 60,
                  highlighted: true,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(PlayingCardView), findsOneWidget);
      }
    });

    testWidgets('PlayingCardView renders dimmed and normal states cleanly', (tester) async {
      const card = PlayingCard.suited(Suit.spades, Rank.ace);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlayingCardView(
                card: card,
                width: 70,
                dimmed: true,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PlayingCardView), findsOneWidget);
    });

    testWidgets('CardBackView renders with and without label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CardBackView(width: 40),
                CardBackView(width: 40, label: '9'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CardBackView), findsNWidgets(2));
      expect(find.text('9'), findsOneWidget);
    });
  });
}
