import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/domain/rules.dart';
import 'package:test_build_game/ui/game/hand_view.dart';
import 'package:test_build_game/ui/game_page.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.instance.enabled.value = false;
  });

  Future<void> pumpGamePage(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = GameBloc(
      random: Random(42),
      humanSeats: const {0, 1, 2, 3},
      botDelay: Duration.zero,
      trickDelay: Duration.zero,
    )..add(const GameStarted());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: GamePage(bloc: bloc),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(GamePage), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  group('GamePage layout', () {
    testWidgets(
      'renders cleanly in Portrait (390x844) without overflow',
      (tester) async {
        await pumpGamePage(tester, size: const Size(390, 844));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'renders cleanly in Landscape (844x390) without overflow',
      (tester) async {
        await pumpGamePage(tester, size: const Size(844, 390));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'renders AutoPlayBanner cleanly in Landscape (844x390) without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final bloc = GameBloc(
          random: Random(42),
          humanSeats: const {0, 1, 2, 3},
          botDelay: Duration.zero,
          trickDelay: Duration.zero,
        )..add(const GameStarted());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: GamePage(bloc: bloc),
            ),
          ),
        );
        await tester.pump();
        bloc.add(const AutoPlayToggled(enabled: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(find.text('البوت شغال'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'HandView keeps state and visible cards when first trick completes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final bloc = GameBloc(
          random: Random(42),
          botDelay: Duration.zero,
          trickDelay: Duration.zero,
        )..add(const GameStarted());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: GamePage(bloc: bloc),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));

        // حفظ عنصر HandView قبل نهاية الأكلة الأولى
        expect(find.byType(HandView), findsOneWidget);
        final elementBefore = tester.element(find.byType(HandView));

        // محاكاة اكتمال الأكلة الأولى وظهور آخر أكلة
        final firstHand = bloc.state.hands[0];
        expect(firstHand, isNotEmpty);
        final dummyCard = firstHand.first;
        bloc.add(StateReceived(bloc.state.copyWith(
          lastTrickWinner: 1,
          lastTrick: [
            PlayedCard(player: 0, card: dummyCard),
          ],
          tricksWon: const [0, 1],
        )));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey('mini_last_trick')), findsOneWidget);
        final elementAfter = tester.element(find.byType(HandView));
        expect(identical(elementBefore, elementAfter), isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
