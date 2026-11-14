import 'package:flutter/foundation.dart';

/// نقطة واحدة لتسجيل الأخطاء. اربطها بـ Sentry أو Firebase Crashlytics:
///   Sentry.captureException(error, stackTrace: stack);
void reportError(Object error, StackTrace? stack, {String? where}) {
  debugPrint('[error${where == null ? '' : ' @ $where'}] $error');
  if (kDebugMode && stack != null) debugPrint('$stack');
}
