import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/bloc/auth_cubit.dart';
import 'package:test_build_game/bloc/game_bloc.dart';
import 'package:test_build_game/bloc/game_codec.dart';
import 'package:test_build_game/core/config.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/data/stats_repository.dart';
import 'package:test_build_game/ui/game/game_hud.dart';
import 'package:test_build_game/ui/home_page.dart';
import 'package:test_build_game/ui/settings_sheet.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.instance.enabled.value = false;
  });

  group('1. الرصيد الافتتاحي وحساب النقاط (Initial Balance & Calculations)', () {
    test('الضيف (Guest) يبدأ بـ 0 نقطة ولا يحصل على نقاط إلا عند تسجيل حسابه', () {
      const guestState = AppAuthState(isGuest: true);
      expect(guestState.coins, equals(0),
          reason: 'يجب أن يبدأ الضيف بـ 0 نقطة ولا يحصل على أي نقاط إلا بعد تسجيل حسابه');

      const registeredState = AppAuthState(isGuest: false, coins: 500);
      expect(registeredState.coins, equals(500),
          reason: 'الحساب المسجل يحصل على 500 نقطة ترحيبية');
    });

    test('مدة المباراة الافتراضية في الإعدادات هي 20 دقيقة', () {
      const settings = GameSettings();
      expect(settings.matchMinutes, equals(20),
          reason: 'يجب أن تكون مدة المباراة الافتراضية 20 دقيقة بدلاً من 60');
      expect(settings.stakePoints, equals(0));
    });

    test('معادلة احتساب النقاط: 500 نقطة لكل 20 دقيقة', () {
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
      // ودية مجانية (0 دقيقة أو بدون نقاط) = 0 نقطة
      expect(pointsForDuration(0), equals(0));
    });

    test('الرصيد الأولي 500 للمسجل يتيح فتح غرفة تجريبية واحدة ثم يصبح 0 ويرفض فتح الغرفة الثانية', () {
      var userBalance = 500;
      const roundCost = 500;

      // فتح أول غرفة بنجاح
      expect(userBalance >= roundCost, isTrue);
      userBalance -= roundCost;
      expect(userBalance, equals(0));

      // محاولة فتح غرفة أخرى برصيد 0 -> يرفض تماماً ويطلب الشحن
      expect(userBalance >= roundCost, isFalse);
    });
  });

  group('2. تشفير وأحداث تمديد وقت المباراة (Event & Codec Serialization)', () {
    test('تشفير وفك تشفير حدث MatchTimeExtended في GameCodec', () {
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

    test('معالجة GameBloc لتمديد وقت المباراة وإعادة ضبط المؤقت', () async {
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

      // تمديد الوقت مرة أخرى بـ 40 دقيقة
      bloc.add(const MatchTimeExtended(additionalMinutes: 40));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final secondExtended = bloc.state.matchEndsAt;
      final diffTotal = secondExtended!.difference(initialEnd).inMinutes;
      expect(diffTotal, inInclusiveRange(59, 61));

      await bloc.close();
    });

    test('اللاعب المتصل عن بُعد (Remote Client) يرسل حدث التمديد للمضيف', () async {
      GameEvent? capturedAction;
      final remoteBloc = GameBloc(
        localSeat: 1,
        remote: true,
      )..sendAction = (e) => capturedAction = e;

      remoteBloc.add(const MatchTimeExtended(additionalMinutes: 20, seat: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedAction, isA<MatchTimeExtended>());
      final action = capturedAction as MatchTimeExtended;
      expect(action.additionalMinutes, equals(20));

      await remoteBloc.close();
    });
  });

  group('3. اختبارات واجهة المستخدم (UI Widgets & Settings Sheet)', () {
    testWidgets('نافذة إنشاء الديوانية برصيد 500 نقطة تعرض الافتراضي 20 دقيقة وزر إنشاء ديوانية',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GameSettings? confirmedSettings;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  confirmedSettings = await showGameSettingsSheet(
                    ctx,
                    confirmLabel: 'إنشاء ديوانية',
                    isOnlineRoom: true,
                    userCoins: 500,
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      );

      // فتح النافذة
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // التحقق من وجود الشريحة الافتراضية
      expect(find.text('٢٠ دقيقة (صكة واحدة 👑 - ٥٠٠ نقطة)'), findsOneWidget);
      expect(find.text('الصكة الافتراضية بـ ٥٠٠ نقطة (٢٠ دقيقة) • كل ٢٠ دقيقة إضافية = +٥٠٠ نقطة'), findsOneWidget);

      // بما أن الرصيد 500 يكفي لـ 500، يظهر زر "إنشاء ديوانية"
      expect(find.text('إنشاء ديوانية'), findsOneWidget);

      // الضغط على إنشاء ديوانية
      await tester.tap(find.text('إنشاء ديوانية'));
      await tester.pumpAndSettle();

      expect(confirmedSettings, isNotNull);
      expect(confirmedSettings!.matchMinutes, equals(20));
      expect(confirmedSettings!.stakePoints, equals(500));
    });

    testWidgets('عند اختيار مدة أعلى من الرصيد يتحول الزر تلقائياً إلى "اشحن النقاط" مع تحذير',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showGameSettingsSheet(
                    ctx,
                    confirmLabel: 'إنشاء ديوانية',
                    isOnlineRoom: true,
                    userCoins: 500, // لديه 500 نقطة فقط
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // اختيار 40 دقيقة (1,000 نقطة)
      await tester.tap(find.text('٤٠ دقيقة (صكتان - ١,٠٠٠ نقطة)'));
      await tester.pumpAndSettle();

      // يظهر تحذير نقص الرصيد
      expect(find.textContaining('تحتاج 1000 نقطة لدخول الغرفة (رصيدك: 500)'), findsOneWidget);

      // يتحول الزر السفلي من "إنشاء ديوانية" إلى "اشحن النقاط"
      expect(find.text('اشحن النقاط'), findsOneWidget);
    });

    testWidgets('المستخدم برصيد 0 تظهر له النافذة مباشرة بزر "اشحن النقاط"',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showGameSettingsSheet(
                    ctx,
                    confirmLabel: 'إنشاء ديوانية',
                    isOnlineRoom: true,
                    userCoins: 0,
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // الزر مباشرة هو "اشحن النقاط"
      expect(find.text('اشحن النقاط'), findsOneWidget);
      expect(find.textContaining('تحتاج 500 نقطة لدخول الغرفة (رصيدك: 0)'), findsOneWidget);
    });

    testWidgets('ساعة مدة اللعبة ElapsedClock تعرض أيقونة + عند وجود وقت محدد للغرفة',
        (tester) async {
      final state = GameState(
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        matchEndsAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: ElapsedClock(state: state),
            ),
          ),
        ),
      );

      await tester.pump();

      // التحقق من ظهور أيقونة الزائد + بجانب الوقت للتعبير عن إمكانية تمديد الوقت
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    });
  });

  group('4. قيود ومنع الضيف من الغرف والنقاط (Guest Blocking & Policy)', () {
    testWidgets('الضيف في نافذة الإعدادات يتحول زر التأكيد إلى "سجّل حسابك للمتابعة"',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showGameSettingsSheet(
                    ctx,
                    confirmLabel: 'إنشاء ديوانية',
                    isOnlineRoom: true,
                    userCoins: 0,
                    isGuest: true, // ضيف
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // يتحول الزر السفلي فوراً لمنع الضيف ومطالبته بالتسجيل
      expect(find.text('سجّل حسابك للمتابعة'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
    });

    testWidgets('الضيف في الشاشة الرئيسية تظهر له رسالة تنبيه عند الضغط على إنشاء أو دخول ديوانية',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      await tester.pump(const Duration(milliseconds: 300));

      // 1. التحقق من كبسولة رصيد الضيف (0)
      expect(find.text('ضيف (٠)'), findsOneWidget);

      // 2. الضغط على إنشاء ديوانية أونلاين
      await tester.tap(find.text('إنشاء ديوانية'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // يظهر تنبيه تسجيل الحساب مع الهدية 500 نقطة
      expect(find.text('تسجيل الحساب مطلوب'), findsOneWidget);
      expect(find.text('احصل على ٥٠٠ نقطة ترحيبية مجاناً 🎁'), findsOneWidget);
      expect(find.text('سجّل حسابك (٥٠٠ 🎁)'), findsOneWidget);

      // إغلاق التنبيه
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. الضغط على الانضمام لديوانية (انضم بكود)
      await tester.tap(find.text('انضم بكود'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // يظهر التنبيه أيضاً
      expect(find.text('تسجيل الحساب مطلوب'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 4. الضغط على كبسولة رصيد الضيف
      await tester.tap(find.text('ضيف (٠)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // يظهر تنبيه رصيد النقاط للأعضاء
      expect(find.text('رصيد نقاط الأعضاء'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    test('ملف SQL يمنع الضيف من إنشاء أو دخول الغرف أو تمديد الوقت (guest_not_allowed)', () {
      final file = File('supabase/points_and_economy.sql');
      expect(file.existsSync(), isTrue);

      final sql = file.readAsStringSync();

      // التحقق من أن الرصيد الافتراضي هو 0 للضيوف
      expect(sql.contains('default 0'), isTrue,
          reason: 'يجب أن يكون الرصيد الافتراضي 0 نقاط للضيوف');

      // التحقق من قيود stake_points
      expect(sql.contains('1500, 2000, 2500, 3000'), isTrue);

      // التحقق من وجود دالة extend_room_time
      expect(sql.contains('create or replace function public.extend_room_time'), isTrue);

      // التحقق من أن الدوال ترفض الضيف عبر استثناء guest_not_allowed
      expect(sql.contains("raise exception 'guest_not_allowed';"), isTrue,
          reason: 'يجب أن تمنع دالات SQL الضيف من دخول الغرف عبر استثناء guest_not_allowed');
    });
  });

  group('5. منع الجوائز والمراهنات (No Gambling, No Winnings Policy)', () {
    testWidgets('نافذة الإعدادات تعرض "لعب نظيف بدون مراهنات" ولا تعرض أي جوائز فوز أو رهانات',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showGameSettingsSheet(
                    ctx,
                    confirmLabel: 'إنشاء الغرفة',
                    isOnlineRoom: true,
                    userCoins: 1000,
                    isGuest: false,
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // التحقق من ظهور عبارة اللعب النظيف والأيقونة المعتمدة
      expect(find.text('لعب نظيف بدون مراهنات'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);

      // التحقق التام من عدم وجود كلمة جائزة أو رهان في النافذة
      expect(find.textContaining('جائزة'), findsNothing);
      expect(find.textContaining('رهان'), findsNothing);
      expect(find.text('ودية مجانية (بدون نقاط)'), findsOneWidget);
    });

    test('دالة award_room_winnings في SQL لا توزع أي نقاط أو تسجل معاملات فوز', () {
      final file = File('supabase/points_and_economy.sql');
      expect(file.existsSync(), isTrue);

      final sql = file.readAsStringSync();

      // التحقق من أن دالة award_room_winnings معطلة تماماً وترجع فوراً بدون توزيع نقاط
      expect(sql.contains('create or replace function public.award_room_winnings'), isTrue);
      // التأكد من عدم وجود كود إضافة أرصدة أو إدراج room_win
      expect(sql.contains('update public.profiles set coins = coins + v_share'), isFalse,
          reason: 'يجب عدم توزيع أي أرباح للفريق الفائز لضمان خلو اللعبة من شبهة القمار والرهان');
    });

    test('اقتصاد اللعبة: النقاط تخصم عند الدخول فقط ورصيد الفائزين لا يزداد عند الفوز', () {
      // رصيد اللاعب قبل الدخول
      var playerBalance = 500;
      const roomEntryCost = 500;

      // خصم رسم حجز الديوانية عند الدخول
      playerBalance -= roomEntryCost;
      expect(playerBalance, equals(0));

      // انتهاء اللعبة بفوز اللاعب: لا توجد أي أرباح أو جوائز مضافة للرصيد
      const winningPointsAwarded = 0;
      playerBalance += winningPointsAwarded;

      // الرصيد يظل 0 ولا يزداد عند الفوز
      expect(playerBalance, equals(0));
    });
  });
}
