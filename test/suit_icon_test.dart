import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/domain/card.dart';
import 'package:test_build_game/ui/suit_icon.dart';

void main() {
  testWidgets('SuitIcon renders all 4 suits without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: const [
              SuitIcon(suit: Suit.spades, size: 24, color: Colors.black),
              SuitIcon(suit: Suit.hearts, size: 24, color: Colors.red),
              SuitIcon(suit: Suit.diamonds, size: 24, color: Colors.red),
              SuitIcon(suit: Suit.clubs, size: 24, color: Colors.black),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SuitIcon), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
