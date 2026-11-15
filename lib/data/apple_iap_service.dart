import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// معرفات باقات الشراء داخل التطبيق لمتجر أبل (StoreKit)
class AppleIapProducts {
  static const String coins1000 = 'com.faisal.koutbo4.coins_1000';
  static const String coins5000 = 'com.faisal.koutbo4.coins_5000';
  static const String coins15000 = 'com.faisal.koutbo4.coins_15000';
  static const String coins50000 = 'com.faisal.koutbo4.coins_50000';

  static const Set<String> allIds = {
    coins1000,
    coins5000,
    coins15000,
    coins50000,
    'com.koutbo4.coins_1000',
    'com.koutbo4.coins_5000',
    'com.koutbo4.coins_15000',
    'com.koutbo4.coins_50000',
  };

  /// خريطة تحويل معرف المنتج إلى عدد النقاط الإجمالي (شاملاً البونص)
  static int coinsForProduct(String productId) {
    if (productId.endsWith('coins_1000')) return 1000;
    if (productId.endsWith('coins_5000')) return 5500; // 5000 + 500
    if (productId.endsWith('coins_15000')) return 17500; // 15000 + 2500
    if (productId.endsWith('coins_50000')) return 65000; // 50000 + 15000
    return 0;
  }
}

/// نتيجة عملية الشراء عبر أبل
class ApplePurchaseResult {
  const ApplePurchaseResult({
    required this.isSuccess,
    this.message,
    this.productId,
    this.transactionId,
    this.newBalance,
  });

  final bool isSuccess;
  final String? message;
  final String? productId;
  final String? transactionId;
  final int? newBalance;
}

/// خدمة Apple In-App Purchase الرسمية (StoreKit)
class AppleIapService {
  AppleIapService({InAppPurchase? iap, SupabaseClient? supabaseClient})
      : _iap = iap ?? InAppPurchase.instance,
        _supabase = supabaseClient;

  static AppleIapService instance = AppleIapService();

  final InAppPurchase _iap;
  final SupabaseClient? _supabase;

  SupabaseClient get _db => _supabase ?? Supabase.instance.client;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};
  bool _isAvailable = false;
  bool _isInitialized = false;

  /// المستمع لأحداث نجاح الشحن داخل الواجهة
  void Function(ApplePurchaseResult)? onPurchaseCompleted;

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  /// تهيئة الاتصال بـ StoreKit وجلب تفاصيل المنتجات والأسعار المعتمدة
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('[AppleIapService] StoreKit غير متاح على هذا الجهاز.');
        _isInitialized = true;
        return false;
      }

      // الاستماع لمجرى عمليات الشراء
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseStreamUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (err) {
          debugPrint('[AppleIapService] خطأ في تدفق المشتريات: $err');
        },
      );

      // تحميل بيانات المنتجات من StoreKit
      await refreshProducts();

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[AppleIapService] خطأ أثناء التهيئة: $e');
      _isInitialized = true;
      _isAvailable = false;
      return false;
    }
  }

  /// جلب وتحديث تفاصيل المنتجات والأسعار المحلية من أبل
  Future<void> refreshProducts() async {
    try {
      final response = await _iap.queryProductDetails(AppleIapProducts.allIds);
      if (response.error != null) {
        debugPrint('[AppleIapService] خطأ جلب المنتجات: ${response.error}');
      }
      _products.clear();
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
    } catch (e) {
      debugPrint('[AppleIapService] تعذر استعلام المنتجات: $e');
    }
  }

  /// تنفيذ عملية شراء باقة مستهلكة (Consumable)
  Future<bool> buyProduct(String productId) async {
    var product = _products[productId];
    if (product == null) {
      debugPrint('[AppleIapService] المنتج غير موجود في الكاش، محاولة إعادة الاستعلام من StoreKit: $productId');
      await refreshProducts();
      product = _products[productId];
    }
    if (product == null) {
      debugPrint('[AppleIapService] المنتج غير موجود في قائمة StoreKit بعد التحديث: $productId');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    } catch (e) {
      debugPrint('[AppleIapService] فشل طلب الشراء من أبل: $e');
      return false;
    }
  }

  /// معالجة استجابة StoreKit لعمليات الشراء
  Future<void> _onPurchaseStreamUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[AppleIapService] عملية شراء معلقة: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handlePurchased(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('[AppleIapService] خطأ في الشراء: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseCompleted?.call(
            ApplePurchaseResult(
              isSuccess: false,
              message: purchase.error?.message ?? 'تم إلغاء أو فشل عملية الدفع عبر أبل.',
              productId: purchase.productID,
            ),
          );
          break;

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseCompleted?.call(
            ApplePurchaseResult(
              isSuccess: false,
              message: 'تم إلغاء عملية الدفع من قبل المستخدم.',
              productId: purchase.productID,
            ),
          );
          break;
      }
    }
  }

  /// التحقق من الشراء وشحن النقاط بقاعدة البيانات ثم إنهاء المعاملة لدى أبل
  Future<void> _handlePurchased(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    final coins = AppleIapProducts.coinsForProduct(productId);
    final orderId = purchase.purchaseID ??
        purchase.transactionDate ??
        DateTime.now().millisecondsSinceEpoch.toString();

    int? newBalance;
    bool credited = false;

    try {
      final user = _db.auth.currentUser;
      if (user != null && coins > 0) {
        final res = await _db.rpc('credit_apple_purchase', params: {
          'p_user_id': user.id,
          'p_coins': coins,
          'p_order_id': orderId,
          'p_product_id': productId,
        });

        if (res != null) {
          credited = true;
          newBalance = (res is num) ? res.toInt() : int.tryParse(res.toString());
        }
      }
    } catch (e) {
      debugPrint('[AppleIapService] تعذر شحن النقاط في قاعدة البيانات: $e');
    }

    // إشعار أبل بانتهاء معالجة المعاملة لعدم تكرار الخصم
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
      } catch (e) {
        debugPrint('[AppleIapService] تعذر إنهاء المعاملة مع StoreKit: $e');
      }
    }

    onPurchaseCompleted?.call(
      ApplePurchaseResult(
        isSuccess: credited,
        message: credited
            ? 'تم شحن $coins نقطة في حسابك بنجاح عبر Apple In-App Purchase!'
            : 'تمت عملية الدفع، ولكن تعذر تحديث الرصيد تلقائياً. تواصل مع الدعم الفني.',
        productId: productId,
        transactionId: orderId,
        newBalance: newBalance,
      ),
    );
  }

  /// استعادة المشتريات السابقة (مطلب أساسي لمراجعة أبل)
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[AppleIapService] تعذر استعادة المشتريات: $e');
    }
  }

  /// إغلاق الموارد عند الخروج
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
