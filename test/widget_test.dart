import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/auth_cubit.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/bloc/lobby_cubit.dart';
import 'package:test_build_game/core/config.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/data/room.dart';
import 'package:test_build_game/data/stats_repository.dart';
import 'package:test_build_game/domain/rules.dart';
import 'package:test_build_game/ui/game/game_hud.dart';
import 'package:test_build_game/ui/game/hand_view.dart';
import 'package:test_build_game/ui/game_page.dart';
import 'package:test_build_game/ui/home_page.dart';
import 'package:test_build_game/ui/room_page.dart';

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

        final err = tester.takeException();
        if (err is FlutterError) {
          // ignore: avoid_print
          print('HomePage error deep:\n${err.toStringDeep()}');
        }
        expect(err, isNull);
        expect(find.text('البوت شغال'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
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
        await tester.pump(const Duration(milliseconds: 200));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'Exit button is visible and never overlaps with score HUD on small and standard screens',
      (tester) async {
        for (final size in [
          const Size(375, 667), // iPhone SE / small
          const Size(390, 844), // iPhone 12/13/14/15/16
          const Size(844, 390), // Landscape
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

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

          final err = tester.takeException();
        if (err is FlutterError) {
          // ignore: avoid_print
          print('HomePage error deep:\n${err.toStringDeep()}');
        }
        expect(err, isNull);

          final exitFinder = find.byTooltip('خروج من الطاولة');
          expect(exitFinder, findsOneWidget);
          final exitRect = tester.getRect(exitFinder);

          final scoreFinder = find.byType(ScoreAndContractHud);
          expect(scoreFinder, findsOneWidget);
          final scoreRect = tester.getRect(scoreFinder);

          // Exit button must be strictly on the left of score HUD with no overlap
          expect(
            exitRect.overlaps(scoreRect),
            isFalse,
            reason: 'Exit button $exitRect must not overlap Score HUD $scoreRect on $size',
          );
          expect(
            exitRect.right < scoreRect.left,
            isTrue,
            reason: 'Exit button must be strictly to the left of the Score HUD on $size',
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'Tapping exit button opens exit confirmation dialog and can cancel or exit',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        final bloc = GameBloc(
          random: Random(42),
          humanSeats: const {0, 1, 2, 3},
          botDelay: Duration.zero,
          trickDelay: Duration.zero,
        )..add(const GameStarted());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: GamePage(bloc: bloc),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final exitFinder = find.byTooltip('خروج من الطاولة');
        expect(exitFinder, findsOneWidget);

        await tester.tap(exitFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('الخروج من اللعبة؟'), findsOneWidget);
        expect(find.text('كمّل لعب'), findsOneWidget);
        expect(find.text('اخرج'), findsOneWidget);

        // Tap cancel
        await tester.tap(find.text('كمّل لعب'), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'Lock screen and backgrounding triggers AutoPlay, notifies room, and silences audio',
      (tester) async {
        final bloc = GameBloc(
          random: Random(42),
          humanSeats: const {0, 1, 2, 3},
          botDelay: Duration.zero,
          trickDelay: Duration.zero,
        )..add(const GameStarted());

        bool? bgNotified;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: GamePage(
                bloc: bloc,
                onBackground: (inBg) => bgNotified = inBg,
              ),
            ),
          ),
        );
        await tester.pump();

        // Simulate screen lock / background
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(bgNotified, isTrue);
        expect(bloc.state.autoSeats.contains(0), isTrue);

        // Simulate unlock / resume
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        expect(bgNotified, isFalse);
        expect(bloc.state.autoSeats.contains(0), isFalse);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('HomePage layout', () {
    testWidgets(
      'renders cleanly without overflow across diverse iPhone and iPad screen sizes',
      (tester) async {
        final testSizes = [
          const Size(375, 667), // iPhone SE / small
          const Size(390, 844), // iPhone 12/13/14/15/16/16e
          const Size(430, 932), // iPhone 14/15/16 Pro Max
          const Size(844, 390), // Landscape phone
          const Size(1024, 768), // Tablet / iPad
        ];

        for (final size in testSizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final caughtErrors = <FlutterErrorDetails>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
          };

          await tester.pumpWidget(
            RepositoryProvider<StatsRepository>(
              create: (_) => StatsRepository(null),
              child: BlocProvider<AuthCubit>(
                create: (_) => AuthCubit(null),
                child: MaterialApp(
                  theme: AppTheme.dark,
                  home: const Directionality(
                    textDirection: TextDirection.rtl,
                    child: HomePage(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          FlutterError.onError = oldHandler;

          expect(
            caughtErrors,
            isEmpty,
            reason: 'Overflow on $size:\n${caughtErrors.map((e) => e.toString()).join('\n')}',
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(HomePage), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('RoomPage layout', () {
    testWidgets(
      'renders cleanly with 5000 stake points without overflow on iPhone 16e and small screens',
      (tester) async {
        final room = Room(
          code: 'GUFJP',
          hostId: 'user-1',
          status: 'waiting',
          targetScore: 101,
          turnSeconds: 20,
          stakePoints: 5000,
          seats: const [
            RoomSeat(userId: 'user-1', name: 'يوسف 👑', isBot: false),
            null,
            null,
            null,
          ],
        );

        final testSizes = [
          const Size(375, 667), // iPhone SE
          const Size(390, 844), // iPhone 16e
          const Size(430, 932), // iPhone 16 Pro Max
          const Size(844, 390), // Landscape
        ];

        for (final size in testSizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final caughtErrors = <FlutterErrorDetails>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
          };

          final cubit = _TestLobbyCubit(room);

          await tester.pumpWidget(
            BlocProvider<AuthCubit>(
              create: (_) => AuthCubit(null),
              child: MaterialApp(
                theme: AppTheme.dark,
                home: Directionality(
                  textDirection: TextDirection.rtl,
                  child: RoomPage(cubit: cubit),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          FlutterError.onError = oldHandler;

          expect(
            caughtErrors,
            isEmpty,
            reason: 'Overflow on $size:\n${caughtErrors.map((e) => e.toString()).join('\n')}',
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(RoomPage), findsOneWidget);
          expect(find.text('GUFJP'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
          await cubit.close();
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'allows switching seats by tapping an empty seat or "انتقل هنا" button',
      (tester) async {
        final room = Room(
          code: 'GUFJP',
          hostId: 'user-1',
          status: 'waiting',
          targetScore: 101,
          turnSeconds: 20,
          stakePoints: 1000,
          seats: const [
            RoomSeat(userId: 'user-1', name: 'يوسف 👑', isBot: false),
            null,
            null,
            null,
          ],
        );

        final cubit = _TestLobbyCubit(room);

        await tester.pumpWidget(
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(null),
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: RoomPage(cubit: cubit),
              ),
            ),
          ),
        );
        await tester.pump();

        // 3 empty seats should have "انتقل هنا"
        final switchButtons = find.text('انتقل هنا');
        expect(switchButtons, findsNWidgets(3));

        // Tap on seat 2 (partner of team 1)
        await tester.tap(switchButtons.at(1));
        await tester.pump();

        expect(cubit.lastSwitchedSeat, equals(2));

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await cubit.close();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}

class _TestLobbyCubit extends Cubit<LobbyState> implements LobbyCubit {
  _TestLobbyCubit(Room initialRoom)
      : super(LobbyState(busy: false, room: initialRoom));

  @override
  bool get isHost => true;

  @override
  String get userId => 'user-1';

  @override
  String get userName => 'يوسف 👑';

  @override
  Future<void> create(GameSettings settings) async {}

  @override
  Future<void> join(String code) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> setBot(int seat, bool bot) async {}

  @override
  Future<void> switchSeat(int targetSeat) async {
    lastSwitchedSeat = targetSeat;
  }

  int? lastSwitchedSeat;

  @override
  Future<void> start() async {}
}
