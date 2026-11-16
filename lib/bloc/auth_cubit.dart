import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/connectivity_service.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AppAuthState extends Equatable {
  const AppAuthState({
    this.status = AuthStatus.loading,
    this.name = '',
    this.userId,
    this.isGuest = true,
    this.busy = false,
    this.error,
    this.coins = 1000,
  });

  final AuthStatus status;
  final String name;
  final String? userId;
  final bool isGuest;
  final bool busy;
  final String? error;
  final int coins;

  AppAuthState copyWith({
    AuthStatus? status,
    String? name,
    String? userId,
    bool? isGuest,
    bool? busy,
    String? error,
    int? coins,
  }) =>
      AppAuthState(
        status: status ?? this.status,
        name: name ?? this.name,
        userId: userId ?? this.userId,
        isGuest: isGuest ?? this.isGuest,
        busy: busy ?? this.busy,
        error: error, // يُمسح تلقائياً إن لم يُمرَّر
        coins: coins ?? this.coins,
      );

  @override
  List<Object?> get props => [status, name, userId, isGuest, busy, error, coins];
}

/// الدخول: بدون Supabase = اسم محلي فقط. معه = ضيف (anonymous) أو إيميل/باسورد.
class AuthCubit extends Cubit<AppAuthState> {
  AuthCubit(this._client) : super(const AppAuthState());

  final sb.SupabaseClient? _client;
  StreamSubscription<sb.AuthState>? _sub;

  bool get online => _client != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final c = _client;
    if (c == null) {
      final saved = prefs.getString('name');
      emit(saved == null
          ? const AppAuthState(status: AuthStatus.signedOut)
          : AppAuthState(
              status: AuthStatus.signedIn,
              name: saved,
              userId: 'local',
            ));
      return;
    }
    _apply(c.auth.currentSession?.user);
    _sub = c.auth.onAuthStateChange.listen((e) => _apply(e.session?.user));
  }

  void _apply(sb.User? u) {
    if (u == null) {
      emit(const AppAuthState(status: AuthStatus.signedOut));
      return;
    }
    final meta = u.userMetadata?['display_name'];
    final name = (meta is String && meta.isNotEmpty)
        ? meta
        : (u.email?.split('@').first ?? 'لاعب');
    emit(AppAuthState(
      status: AuthStatus.signedIn,
      name: name,
      userId: u.id,
      isGuest: u.isAnonymous,
    ));

    // مزامنة فورية للبروفايل مع قاعدة البيانات وجلب الرصيد
    final c = _client;
    if (c != null) {
      c.from('profiles').upsert({
        'id': u.id,
        'name': name,
        'is_guest': u.isAnonymous,
        'updated_at': DateTime.now().toIso8601String(),
      }).then((_) {
        refreshCoins();
      }).catchError((_) {
        refreshCoins();
      });
    }
  }

  /// تحديث رصيد النقاط محلياً فوراً
  void setCoins(int newCoins) {
    if (!isClosed) emit(state.copyWith(coins: newCoins));
  }

  /// تحديث رصيد النقاط من Supabase
  Future<void> refreshCoins() async {
    final c = _client;
    final uid = state.userId;
    if (c == null || uid == null || uid == 'local') return;
    try {
      final row = await c.from('profiles').select('coins').eq('id', uid).maybeSingle();
      if (row != null && row['coins'] != null) {
        final bal = (row['coins'] as num).toInt();
        if (!isClosed) emit(state.copyWith(coins: bal));
      }
    } catch (_) {}
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
  }

  Future<void> updateName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    await _saveName(clean);
    final c = _client;
    if (c != null && c.auth.currentUser != null) {
      try {
        await c.auth.updateUser(sb.UserAttributes(data: {'display_name': clean}));
        await c.from('profiles').upsert({
          'id': c.auth.currentUser!.id,
          'name': clean,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    emit(state.copyWith(name: clean));
  }

  Future<void> signInGuest(String name) async {
    var clean = name.trim();
    if (clean.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('name');
      clean = (saved != null && saved.trim().isNotEmpty)
          ? saved.trim()
          : 'لاعب_${Random().nextInt(9000) + 1000}';
    }
    await _saveName(clean);
    final c = _client;
    // إذا لم يكن هناك إنترنت أو Supabase غير مفعل، الدخول فوري في وضع الأوفلاين المحلي
    if (c == null || !ConnectivityService.instance.isOnline) {
      emit(AppAuthState(
        status: AuthStatus.signedIn,
        name: clean,
        userId: 'local',
        isGuest: true,
      ));
      return;
    }
    try {
      emit(state.copyWith(busy: true));
      await c.auth
          .signInAnonymously(data: {'display_name': clean})
          .timeout(const Duration(seconds: 4));
      emit(state.copyWith(busy: false));
    } catch (_) {
      // في حالة فشل الاتصال بالشبكة، يتم التحويل تلقائياً لوضع الأوفلاين للعب دون توقف
      emit(AppAuthState(
        status: AuthStatus.signedIn,
        name: clean,
        userId: 'local',
        isGuest: true,
      ));
    }
  }

  /// الدخول المباشر في وضع الأوفلاين (بدون إنترنت)
  Future<void> signInOffline({String? name}) async {
    var clean = (name ?? '').trim();
    if (clean.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('name');
      clean = (saved != null && saved.trim().isNotEmpty)
          ? saved.trim()
          : 'لاعب_${Random().nextInt(9000) + 1000}';
    }
    await _saveName(clean);
    emit(AppAuthState(
      status: AuthStatus.signedIn,
      name: clean,
      userId: 'local',
      isGuest: true,
    ));
  }

  Future<void> signUp(String name, String email, String password) async {
    final c = _client;
    if (c == null) return;
    if (name.trim().isEmpty) {
      emit(state.copyWith(error: 'اكتب اسمك'));
      return;
    }
    await _saveName(name.trim());
    await _run(() async {
      final res = await c.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      );
      if (res.session == null) {
        throw sb.AuthException('تحقق من بريدك الإلكتروني لتأكيد الحساب ثم سجّل الدخول');
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    final c = _client;
    if (c == null) return;
    await _run(() => c.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ));
  }

  Future<void> signOut() async {
    final c = _client;
    if (c != null) {
      await c.auth.signOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('name');
      emit(const AppAuthState(status: AuthStatus.signedOut));
    }
  }

  /// حذف الحساب نهائياً (مطلوب لمتاجر التطبيقات). يرجع true عند النجاح.
  Future<bool> deleteAccount() async {
    final c = _client;
    if (c == null) return false;
    try {
      await c.rpc('delete_account');
      await c.auth.signOut();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    emit(state.copyWith(busy: true));
    try {
      await action();
      emit(state.copyWith(busy: false));
    } on sb.AuthException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'تعذر الاتصال، حاول مرة أخرى'));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
