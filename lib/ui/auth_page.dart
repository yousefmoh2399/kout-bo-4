import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../core/theme.dart';
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
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<AuthCubit, AppAuthState>(
                  builder: (context, s) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('♠ ♥ ♦ ♣',
                            style: TextStyle(fontSize: 22, color: AppColors.gold, letterSpacing: 6)),
                        const SizedBox(height: 6),
                        Text('كوت بو',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                )),
                        const Text('لعبة الورق الخليجية', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 28),
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
                                const SizedBox(height: 12),
                                Text(s.error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.danger)),
                              ],
                              const SizedBox(height: 18),
                              if (!_emailMode)
                                GoldButton(
                                  label: cubit.online ? 'ادخل كضيف' : 'ابدأ اللعب',
                                  icon: Icons.play_arrow_rounded,
                                  busy: s.busy,
                                  onPressed: () => cubit.signInGuest(_name.text),
                                )
                              else
                                GoldButton(
                                  label: _registerMode ? 'إنشاء حساب' : 'تسجيل الدخول',
                                  busy: s.busy,
                                  onPressed: () => _registerMode
                                      ? cubit.signUp(_name.text, _email.text, _password.text)
                                      : cubit.signIn(_email.text, _password.text),
                                ),
                              if (cubit.online) ...[
                                const SizedBox(height: 10),
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
                                    child: Text(_registerMode ? 'عندي حساب بالفعل' : 'ماعندي حساب؟ سجّل الآن'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        if (!cubit.online)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'وضع غير متصل: اللعب ضد البوتات فقط.\nلتفعيل الغرف والدعوات اضبط مفاتيح Supabase (راجع README).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12),
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
