import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/auth_cubit.dart';
import 'core/config.dart';
import 'core/crash.dart';
import 'core/sound.dart';
import 'core/theme.dart';
import 'data/stats_repository.dart';
import 'ui/auth_page.dart';
import 'ui/home_page.dart';
import 'ui/strings.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack, where: 'flutter');
    };
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    SupabaseClient? client;
    if (AppConfig.isOnlineConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      client = Supabase.instance.client;
    }
    await SoundService.instance.init();
    runApp(KoutBoApp(client: client));
  }, (error, stack) => reportError(error, stack, where: 'zone'));
}

class KoutBoApp extends StatelessWidget {
  const KoutBoApp({super.key, this.client});

  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<StatsRepository>(
      create: (_) => StatsRepository(client),
      child: BlocProvider<AuthCubit>(
        create: (_) => AuthCubit(client)..init(),
        child: MaterialApp(
          title: S.appTitle,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.dark,
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppAuthState>(
      builder: (context, s) {
        switch (s.status) {
          case AuthStatus.loading:
            return const _LuxuryLoadingScreen();
          case AuthStatus.signedOut:
            return const AuthPage();
          case AuthStatus.signedIn:
            return const HomePage();
        }
      },
    );
  }
}

class _LuxuryLoadingScreen extends StatelessWidget {
  const _LuxuryLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeltBackground(
        animated: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF134832), Color(0xFF062116)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.gold, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(75),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '♠',
                  style: TextStyle(
                    fontSize: 42,
                    color: AppColors.goldLight,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                S.appTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.goldLight,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.goldLight,
                  backgroundColor: AppColors.gold.withAlpha(45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
