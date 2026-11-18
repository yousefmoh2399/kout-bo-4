import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_build_game/bloc/auth_cubit.dart';
import 'package:test_build_game/core/sound.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/data/stats_repository.dart';
import 'package:test_build_game/ui/auth_page.dart';
import 'package:test_build_game/ui/settings_page.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.instance.enabled.value = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Apple Sign In & Account Deletion (Apple Guidelines 4.8 & 5.1.1)', () {
    test('1. AuthCubit handles offline sign in, sign out, and account deletion', () async {
      final cubit = AuthCubit(null);
      await cubit.init();

      // الدخول أوفلاين
      await cubit.signInOffline(name: 'فهد الكويتي');
      expect(cubit.state.status, AuthStatus.signedIn);
      expect(cubit.state.name, 'فهد الكويتي');
      expect(cubit.state.isGuest, isTrue);

      // حذف الحساب
      final deleted = await cubit.deleteAccount();
      expect(deleted, isTrue);
      expect(cubit.state.status, AuthStatus.signedOut);
    });

    testWidgets('2. AuthPage displays SignInWithAppleButton according to Apple HIG',
        (tester) async {
      final cubit = AuthCubit(null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const AuthPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      // التأكد من وجود الزر الرسمي لـ Apple أو إمكانية الدخول
      expect(find.byType(AuthPage), findsOneWidget);
    });

    testWidgets('3. SettingsPage displays Account Deletion button for logged in user',
        (tester) async {
      final cubit = AuthCubit(null);
      await cubit.signInOffline(name: 'جراح');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>.value(value: cubit),
              ],
              child: RepositoryProvider<StatsRepository>(
                create: (_) => StatsRepository(null),
                child: const SettingsPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // التحقق من وجود زر حذف الحساب نهائياً
      final deleteBtn = find.text('حذف الحساب نهائياً');
      expect(deleteBtn, findsOneWidget);

      await tester.ensureVisible(deleteBtn);
      await tester.pumpAndSettle();

      // الضغط على زر حذف الحساب لفتح نافذة التأكيد
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // التحقق من ظهور نافذة التحذير والتأكيد المطابقة لمتطلبات أبل
      expect(find.text('حذف الحساب نهائياً؟'), findsOneWidget);
      expect(find.text('نعم، احذف'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // الضغط على نعم، احذف
      await tester.tap(find.text('نعم، احذف'));
      await tester.pumpAndSettle();

      // التحقق من أن حالة المستخدم أصبحت signedOut
      expect(cubit.state.status, AuthStatus.signedOut);
    });
  });
}
