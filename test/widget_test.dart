import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
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
  });
}
