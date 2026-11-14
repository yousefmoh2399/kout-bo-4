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

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack, where: 'flutter');
    };
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    SupabaseClient? client;
    if (AppConfig.isOnlineConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
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
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.signedOut:
            return const AuthPage();
          case AuthStatus.signedIn:
            return const HomePage();
        }
      },
    );
  }
}
