import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../bloc/auth_cubit.dart';
import '../core/connectivity_service.dart';
import '../core/theme.dart';
import 'suit_icon.dart';
import 'widgets.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _emailMode = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    return Scaffold(
      body: FeltBackground(
        animated: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<AuthCubit, AppAuthState>(
                  builder: (context, s) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withAlpha(80), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SuitIcon.spades(size: 15, color: AppColors.goldLight),
                              SizedBox(width: 12),
                              SuitIcon.hearts(size: 15, color: AppColors.goldLight),
                              SizedBox(width: 12),
                              SuitIcon.diamonds(size: 15, color: AppColors.goldLight),
                              SizedBox(width: 12),
                              SuitIcon.clubs(size: 15, color: AppColors.goldLight),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'كوت بو ٤',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(160),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                  Shadow(
                                    color: AppColors.gold.withAlpha(120),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                        ),
                        const Text(
                          'لعبة الورق الخليجية الأصيلة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ValueListenableBuilder<bool>(
                          valueListenable: ConnectivityService.instance.isOnlineNotifier,
                          builder: (context, isOnline, _) {
                            return GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!isOnline)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x33F59E0B),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.wifi_off_rounded,
                                            color: Color(0xFFFBBF24),
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'لا يوجد اتصال بالإنترنت • وضع الأوفلاين مفعّل\nيمكنك بدء اللعب فوراً ضد البوتات.',
                                              style: TextStyle(
                                                color: Color(0xFFFDE68A),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (!_emailMode || _registerMode)
                                    TextField(
                                      controller: _name,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'اسمك في اللعبة',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                    ),
                                  if (_emailMode) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'البريد الإلكتروني',
                                        prefixIcon: Icon(Icons.mail_outline),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _password,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                    ),
                                  ],
                                  if (s.error != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      s.error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  if (!_emailMode)
                                    GoldButton(
                                      label: !isOnline
                                          ? 'ابدأ اللعب أوفلاين (بدون إنترنت)'
                                          : (cubit.online ? 'ادخل كضيف' : 'ابدأ اللعب'),
                                      icon: !isOnline
                                          ? Icons.offline_bolt_rounded
                                          : Icons.play_arrow_rounded,
                                      busy: s.busy,
                                      onPressed: () => !isOnline
                                          ? cubit.signInOffline(name: _name.text)
                                          : cubit.signInGuest(_name.text),
                                    )
                                  else
                                    GoldButton(
                                      label: _registerMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                                      busy: s.busy,
                                      onPressed: () {
                                        if (!isOnline) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تسجيل الدخول بالبريد يتطلب اتصالاً بالإنترنت.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        _registerMode
                                            ? cubit.signUp(_name.text, _email.text, _password.text)
                                            : cubit.signIn(_email.text, _password.text);
                                      },
                                    ),
                                  if (cubit.online && isOnline) ...[
                                    const SizedBox(height: 12),
                                    SignInWithAppleButton(
                                      onPressed: s.busy
                                          ? () {}
                                          : () => cubit.signInWithApple(),
                                      text: 'تسجيل الدخول بواسطة Apple',
                                      height: 48,
                                      borderRadius: BorderRadius.circular(14),
                                      style: SignInWithAppleButtonStyle.black,
                                    ),
                                    const SizedBox(height: 12),
                                    GoldButton(
                                      label: _emailMode
                                          ? 'العودة للدخول كضيف'
                                          : 'الدخول بالبريد الإلكتروني',
                                      outlined: true,
                                      onPressed: () => setState(() {
                                        _emailMode = !_emailMode;
                                        _registerMode = false;
                                      }),
                                    ),
                                    if (_emailMode)
                                      TextButton(
                                        onPressed: () => setState(() => _registerMode = !_registerMode),
                                        child: Text(
                                          _registerMode
                                              ? 'عندي حساب بالفعل؟ سجّل دخول'
                                              : 'ليس لديك حساب؟ سجّل الآن',
                                          style: const TextStyle(
                                            color: AppColors.goldLight,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        if (!cubit.online)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(60),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                'وضع بدون اتصال: اللعب متاح ضد البوتات.\nلتفعيل الغرف واللعب أونلاين اضبط مفاتيح Supabase.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
