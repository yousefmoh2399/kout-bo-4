import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/auth_cubit.dart';
import 'core/config.dart';
import 'core/connectivity_service.dart';
import 'core/crash.dart';
import 'core/sound.dart';
import 'core/theme.dart';
import 'data/stats_repository.dart';
import 'ui/auth_page.dart';
import 'ui/home_page.dart';
import 'ui/strings.dart';
import 'ui/suit_icon.dart';
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
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
        );
      } catch (_) {
        // تم التهيئة مسبقاً (في حالة Hot Restart)
      }
      try {
        client = Supabase.instance.client;
      } catch (_) {}
    }
    await SoundService.instance.init();
    await ConnectivityService.instance.init();
    runApp(KoutBoApp(client: client));
  }, (error, stack) => reportError(error, stack, where: 'zone'));
}

class KoutBoApp extends StatefulWidget {
  const KoutBoApp({super.key, this.client});

  final SupabaseClient? client;

  @override
  State<KoutBoApp> createState() => _KoutBoAppState();
}

class _KoutBoAppState extends State<KoutBoApp> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connSub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;
      _messengerKey.currentState?.removeCurrentSnackBar();
      if (!isOnline) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF92400E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 4),
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Color(0xFFFDE68A), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لا يوجد اتصال بالإنترنت • تم تفعيل وضع الأوفلاين (اللعب الفردي ضد البوتات متاح)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 3),
            content: const Row(
              children: [
                Icon(Icons.wifi_rounded, color: Color(0xFF6EE7B7), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تمت استعادة الاتصال بالإنترنت • وضع الأونلاين متاح الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SoundService.instance.onAppLifecycleChanged(state);
    if (state == AppLifecycleState.resumed) {
      ConnectivityService.instance.checkInternet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<StatsRepository>(
      create: (_) => StatsRepository(widget.client),
      child: BlocProvider<AuthCubit>(
        create: (_) => AuthCubit(widget.client)..init(),
        child: MaterialApp(
          scaffoldMessengerKey: _messengerKey,
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
                child: const SuitIcon.spades(
                  size: 42,
                  color: AppColors.goldLight,
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
