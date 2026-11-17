import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/domain/card.dart';
import 'package:test_build_game/domain/rules.dart';
import 'package:test_build_game/ui/game_page.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.instance.enabled.value = false;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  testWidgets('Render and capture 3D Table in Landscape and Portrait',
      (tester) async {
    final hand0 = [
      const PlayingCard.suited(Suit.hearts, Rank.ace),
      const PlayingCard.suited(Suit.hearts, Rank.king),
      const PlayingCard.suited(Suit.hearts, Rank.queen),
      const PlayingCard.suited(Suit.hearts, Rank.jack),
      const PlayingCard.suited(Suit.spades, Rank.ace),
      const PlayingCard.suited(Suit.diamonds, Rank.king),
      const PlayingCard.joker(JokerKind.red),
      const PlayingCard.suited(Suit.clubs, Rank.ten),
    ];
    final hand1 = List.generate(
      7,
      (i) => PlayingCard.suited(Suit.clubs, Rank.values[i]),
    );
    final hand2 = List.generate(
      7,
      (i) => PlayingCard.suited(Suit.diamonds, Rank.values[i]),
    );
    final hand3 = List.generate(
      7,
      (i) => PlayingCard.suited(Suit.spades, Rank.values[i]),
    );

    final trickPlays = [
      const PlayedCard(
        player: 2,
        card: PlayingCard.suited(Suit.hearts, Rank.nine),
      ),
      const PlayedCard(
        player: 1,
        card: PlayingCard.suited(Suit.hearts, Rank.seven),
      ),
      const PlayedCard(
        player: 3,
        card: PlayingCard.suited(Suit.diamonds, Rank.eight),
      ),
    ];

    final state = GameState(
      phase: GamePhase.playing,
      scores: const [14, 8],
      tricksWon: const [2, 1],
      hands: [hand0, hand1, hand2, hand3],
      currentPlayer: 0,
      bidder: 0,
      highestBid: 6,
      bids: const [6, 0, 5, 0],
      dealer: 1,
      trump: Suit.hearts,
      roundNumber: 1,
      names: const ['أنت (VIP)', 'عبود 🤖', 'مريم (الشريك)', 'عباس 🤖'],
      trick: Trick(plays: trickPlays),
      turnEndsAt: DateTime.now().add(const Duration(seconds: 18)),
      autoSeats: const {1, 3},
    );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.feltDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.felt,
        brightness: Brightness.dark,
        primary: AppColors.gold,
      ),
    );

    // --- Capture Landscape (844 x 390 - Matching competitor screenshot) ---
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;

    final blocLandscape = GameBloc(
      localSeat: 0,
      names: state.names,
    )..add(StateReceived(state));

    final landscapeKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: landscapeKey,
            child: SizedBox(
              width: 844,
              height: 390,
              child: GamePage(bloc: blocLandscape),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));

    await tester.runAsync(() async {
      final boundary = landscapeKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      const outPathLandscape =
          '/Users/yousef/.gemini/antigravity/brain/2760fc8d-d891-4b14-8959-1191e29d506b/game_3d_table_landscape.png';
      File(outPathLandscape).writeAsBytesSync(bytes);
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // --- Capture Portrait (390 x 844) ---
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    final blocPortrait = GameBloc(
      localSeat: 0,
      names: state.names,
    )..add(StateReceived(state));

    final portraitKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: portraitKey,
            child: SizedBox(
              width: 390,
              height: 844,
              child: GamePage(bloc: blocPortrait),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));

    await tester.runAsync(() async {
      final boundary = portraitKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      const outPathPortrait =
          '/Users/yousef/.gemini/antigravity/brain/2760fc8d-d891-4b14-8959-1191e29d506b/game_3d_table_portrait.png';
      File(outPathPortrait).writeAsBytesSync(bytes);
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
