import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum AuthStatus { loading, signedOut, signedIn }

class AppAuthState extends Equatable {
  const AppAuthState({
    this.status = AuthStatus.loading,
    this.name = '',
    this.userId,
    this.isGuest = true,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final String name;
  final String? userId;
  final bool isGuest;
  final bool busy;
  final String? error;

  AppAuthState copyWith({
    AuthStatus? status,
    String? name,
    String? userId,
    bool? isGuest,
    bool? busy,
    String? error,
  }) =>
      AppAuthState(
        status: status ?? this.status,
        name: name ?? this.name,
        userId: userId ?? this.userId,
        isGuest: isGuest ?? this.isGuest,
        busy: busy ?? this.busy,
        error: error, // يُمسح تلقائياً إن لم يُمرَّر
      );

  @override
  List<Object?> get props => [status, name, userId, isGuest, busy, error];
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
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
  }

  Future<void> signInGuest(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      emit(state.copyWith(error: 'اكتب اسمك أولاً'));
      return;
    }
    await _saveName(clean);
    final c = _client;
    if (c == null) {
      emit(AppAuthState(
        status: AuthStatus.signedIn,
        name: clean,
        userId: 'local',
      ));
      return;
    }
    await _run(() => c.auth.signInAnonymously(data: {'display_name': clean}));
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
