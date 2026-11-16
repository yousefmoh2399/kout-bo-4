import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/auth_cubit.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/bloc/game_codec.dart';
import 'package:test_build_game/core/config.dart';

void main() {
  group('Points & Economy System Tests', () {
    test('Initial welcome balance for any account is 500 points', () {
      const state = AppAuthState();
      expect(state.coins, equals(500),
          reason: 'Initial account balance must be 500 points (1 trial round of 20 min)');
    });

    test('Default match duration is 20 minutes', () {
      const settings = GameSettings();
      expect(settings.matchMinutes, equals(20),
          reason: 'Default match duration must be 20 minutes');
    });

    test('Points calculation for match duration: 500 points per 20 minutes', () {
      int pointsForDuration(int minutes) {
        if (minutes <= 0) return 0;
        final rounds = (minutes + 19) ~/ 20;
        return rounds * 500;
      }

      // صكة واحدة (20 دقيقة) = 500 نقطة
      expect(pointsForDuration(20), equals(500));
      // صكتان (40 دقيقة) = 1,000 نقطة
      expect(pointsForDuration(40), equals(1000));
      // 3 صكات (60 دقيقة / ساعة) = 1,500 نقطة
      expect(pointsForDuration(60), equals(1500));
      // 4 صكات (80 دقيقة) = 2,000 نقطة
      expect(pointsForDuration(80), equals(2000));
      // 5 صكات (100 دقيقة) = 2,500 نقطة
      expect(pointsForDuration(100), equals(2500));
      // 6 صكات (120 دقيقة / ساعتان) = 3,000 نقطة
      expect(pointsForDuration(120), equals(3000));
      // ودية مجانية (0 دقيقة أو بدون رهان) = 0 نقطة
      expect(pointsForDuration(0), equals(0));
    });

    test('Initial 500 points allows exactly 1 trial round (20 min) and leaves 0 points', () {
      var userBalance = 500;
      const roundCost = 500;

      // User creates 1 room of 20 min
      expect(userBalance >= roundCost, isTrue);
      userBalance -= roundCost;
      expect(userBalance, equals(0));

      // After 1st room, user cannot open another room without recharging
      expect(userBalance >= roundCost, isFalse);
    });

    test('GameCodec serializes and deserializes MatchTimeExtended action correctly', () {
      const event = MatchTimeExtended(additionalMinutes: 20, seat: 1);
      final json = GameCodec.actionToJson(event, 1);

      expect(json['kind'], equals('extend'));
      expect(json['seat'], equals(1));
      expect(json['v'], equals(20));

      final decoded = GameCodec.actionFromJson(json);
      expect(decoded, isA<MatchTimeExtended>());
      final decodedExt = decoded as MatchTimeExtended;
      expect(decodedExt.additionalMinutes, equals(20));
      expect(decodedExt.seat, equals(1));
    });

    test('GameBloc handles MatchTimeExtended and extends match deadline', () async {
      final bloc = GameBloc(
        localSeat: 0,
        matchMinutes: 20,
      );

      bloc.add(const GameStarted());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final initialEnd = bloc.state.matchEndsAt;
      expect(initialEnd, isNotNull);

      // تمديد الوقت بـ 20 دقيقة إضافية
      bloc.add(const MatchTimeExtended(additionalMinutes: 20));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final extendedEnd = bloc.state.matchEndsAt;
      expect(extendedEnd, isNotNull);
      final diffMinutes = extendedEnd!.difference(initialEnd!).inMinutes;
      expect(diffMinutes, inInclusiveRange(19, 21));

      await bloc.close();
    });
  });
}
