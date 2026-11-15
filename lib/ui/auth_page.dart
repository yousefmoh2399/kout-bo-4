import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
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
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                  label: cubit.online ? 'ادخل كضيف' : 'ابدأ اللعب',
                                  icon: Icons.play_arrow_rounded,
                                  busy: s.busy,
                                  onPressed: () => cubit.signInGuest(_name.text),
                                )
                              else
                                GoldButton(
                                  label: _registerMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                                  busy: s.busy,
                                  onPressed: () => _registerMode
                                      ? cubit.signUp(_name.text, _email.text, _password.text)
                                      : cubit.signIn(_email.text, _password.text),
                                ),
                              if (cubit.online) ...[
                                const SizedBox(height: 12),
                                GoldButton(
                                  label: _emailMode ? 'العودة للدخول كضيف' : 'الدخول بالبريد الإلكتروني',
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
                                      _registerMode ? 'عندي حساب بالفعل؟ سجّل دخول' : 'ليس لديك حساب؟ سجّل الآن',
                                      style: const TextStyle(
                                        color: AppColors.goldLight,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
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
