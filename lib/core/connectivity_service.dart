import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// خدمة فحص ومراقبة الاتصال بالإنترنت بشكل لحظي ومستمر.
/// تكتشف انقطاع الإنترنت، وتفعّل وضع الأوفلاين فوراً، وتنبه عند عودة الاتصال.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool get isOnline => isOnlineNotifier.value;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodicTimer;
  bool _initialized = false;

  /// تهيئة الخدمة وبدء الاستماع لتغيرات الشبكة
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // فحص مبدئي سريع
    await checkInternet();

    // الاستماع للتغيرات من نظام التشغيل (واي فاي / بيانات خلوية / انقطاع)
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none) && results.length == 1) {
        _setOnline(false);
      } else {
        // يوجد اتصال شبكي، نتحقق من وصول الإنترنت الفعلي
        checkInternet();
      }
    });

    // مؤقت دوري خفيف للتأكد في حال انقطاع الـ DSL أو انتهاء باقة البيانات
    _periodicTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      checkInternet();
    });
  }

  /// فحص مباشر وحقيقي لوصول الإنترنت
  Future<bool> checkInternet({Duration timeout = const Duration(seconds: 3)}) async {
    bool hasInternet = false;
    try {
      // 1. فحص مبدئي لبطاقة الشبكة
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none) && results.length == 1) {
        _setOnline(false);
        return false;
      }

      // 2. محاولة اتصال سريع بمنفذ DNS موثوق (Cloudflare DNS 1.1.1.1)
      final socket = await Socket.connect('1.1.1.1', 53, timeout: timeout);
      socket.destroy();
      hasInternet = true;
    } catch (_) {
      // 3. مسار بديل عبر استعلام DNS لـ google.com
      try {
        final lookup = await InternetAddress.lookup('google.com').timeout(timeout);
        hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }
    }

    _setOnline(hasInternet);
    return hasInternet;
  }

  void _setOnline(bool online) {
    if (isOnlineNotifier.value != online) {
      isOnlineNotifier.value = online;
      _controller.add(online);
    }
  }

  void dispose() {
    _sub?.cancel();
    _periodicTimer?.cancel();
    _controller.close();
    _initialized = false;
  }
}
