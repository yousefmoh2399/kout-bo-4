import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/auth_cubit.dart';
import '../core/config.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../data/apple_iap_service.dart';
import '../data/myfatoorah_service.dart';
import 'effects.dart';
import 'widgets.dart';

/// باقة النقاط المتاحة للشراء في المتجر بالدينار الكويتي (KWD)
class CoinPackage {
  const CoinPackage({
    required this.id,
    required this.title,
    required this.coins,
    required this.bonus,
    required this.kwdAmount,
    required this.priceString,
    required this.icon,
    this.badge,
    this.isPopular = false,
  });

  final String id;
  final String title;
  final int coins;
  final int bonus;
  final double kwdAmount;
  final String priceString;
  final IconData icon;
  final String? badge;
  final bool isPopular;

  int get totalCoins => coins + bonus;
}

const List<CoinPackage> kCoinPackages = [
  CoinPackage(
    id: 'com.faisal.koutbo4.coins_1000',
    title: 'كيس النقاط',
    coins: 1000,
    bonus: 0,
    kwdAmount: 0.500,
    priceString: '0.500 د.ك',
    icon: Icons.monetization_on_outlined,
  ),
  CoinPackage(
    id: 'com.faisal.koutbo4.coins_5000',
    title: 'صرة النقاط',
    coins: 5000,
    bonus: 500,
    kwdAmount: 1.750,
    priceString: '1.750 د.ك',
    icon: Icons.savings_outlined,
    badge: 'الأكثر طلباً 🔥',
    isPopular: true,
  ),
  CoinPackage(
    id: 'com.faisal.koutbo4.coins_15000',
    title: 'صندوق النقاط',
    coins: 15000,
    bonus: 2500,
    kwdAmount: 4.500,
    priceString: '4.500 د.ك',
    icon: Icons.inventory_2_outlined,
    badge: '+17% بونص',
  ),
  CoinPackage(
    id: 'com.faisal.koutbo4.coins_50000',
    title: 'خزانة النقاط الكبرى',
    coins: 50000,
    bonus: 15000,
    kwdAmount: 12.000,
    priceString: '12.000 د.ك',
    icon: Icons.workspace_premium_rounded,
    badge: 'القيمة الأفضل 👑',
  ),
];

/// شاشة متجر النقاط والدفع عبر ماي فاتورة (MyFatoorah KNET & Cards)
class StorePage extends StatefulWidget {
  const StorePage({super.key, this.requiredPoints});

  /// النقاط المطلوبة للغرفة إن فتح المتجر بسبب نقص الرصيد
  final int? requiredPoints;

  static Future<void> show(BuildContext context, {int? requiredPoints}) {
    return Navigator.push(
      context,
      appRoute<void>(StorePage(requiredPoints: requiredPoints)),
    );
  }

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int _currentCoins = 1000;
  bool _loading = true;
  String? _purchasingId;

  AppleIapService get _iap => AppleIapService.instance;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _initAppleIap();
  }

  void _initAppleIap() {
    _iap.onPurchaseCompleted = _onApplePurchaseCompleted;
    _iap.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_iap.onPurchaseCompleted == _onApplePurchaseCompleted) {
      _iap.onPurchaseCompleted = null;
    }
    super.dispose();
  }

  void _onApplePurchaseCompleted(ApplePurchaseResult result) {
    if (!mounted) return;
    setState(() => _purchasingId = null);

    if (result.isSuccess) {
      _fetchBalance();
      context.read<AuthCubit>().refreshCoins();
      SoundService.instance.play(Sfx.win);

      showLuxuryDialog<void>(
        context: context,
        title: 'تم الشحن بنجاح!',
        icon: Icons.check_circle_rounded,
        accentColor: AppColors.goldLight,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.message ?? 'تم شحن النقاط في حسابك بنجاح!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (result.transactionId != null) ...[
              const SizedBox(height: 6),
              Text(
                'رقم المعاملة: ${result.transactionId}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
        actions: [
          GoldButton(
            label: 'رائع',
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    } else {
      showSnack(context, result.message ?? 'تعذر إتمام عملية الدفع عبر أبل.');
    }
  }

  Future<void> _restorePurchases() async {
    showSnack(context, 'جارٍ استعادة المشتريات من Apple App Store...');
    await _iap.restorePurchases();
  }

  Future<void> _fetchBalance() async {
    setState(() => _loading = true);
    final uid = context.read<AuthCubit>().state.userId;
    if (AppConfig.isOnlineConfigured && uid != null && uid != 'local') {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('coins')
            .eq('id', uid)
            .maybeSingle();
        if (row != null && row['coins'] != null) {
          _currentCoins = (row['coins'] as num).toInt();
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  /// تنفيذ عملية الشراء والدفع
  Future<void> _handlePurchase(CoinPackage package) async {
    SoundService.instance.play(Sfx.click);
    final auth = context.read<AuthCubit>().state;
    final uid = auth.userId;

    // التحقق الصارم: إذا كان اللاعب داخلاً كـ Guest أو غير مسجل
    if (auth.isGuest || uid == null || uid == 'local') {
      await showLuxuryDialog<void>(
        context: context,
        title: 'تسجيل الدخول مطلوب',
        icon: Icons.account_circle_outlined,
        accentColor: AppColors.gold,
        content: const Text(
          'أنت مسجل حالياً كـ (زائر / Guest).\nيرجى تسجيل الدخول بحسابك أولاً لحفظ رصيد نقاطك ومشترياتك بأمان.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          GoldButton(
            label: 'تسجيل الدخول الآن',
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().signOut();
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
      return;
    }

    final hasApple = _iap.isAvailable;
    final hasMyFatoorah = AppConfig.isMyFatoorahConfigured;

    if (hasApple && hasMyFatoorah) {
      await _showPaymentMethodSheet(package, uid, auth.name);
    } else if (hasApple) {
      await _purchaseWithApple(package);
    } else {
      await _purchaseWithMyFatoorah(package, uid, auth.name);
    }
  }

  /// شراء الباقة عبر متجر أبل الرسمي (StoreKit / Apple Pay)
  Future<void> _purchaseWithApple(CoinPackage package) async {
    setState(() => _purchasingId = package.id);
    final started = await _iap.buyProduct(package.id);
    if (!started && mounted) {
      setState(() => _purchasingId = null);
      await showLuxuryDialog<void>(
        context: context,
        title: 'باقة Apple قيد المزامنة',
        icon: Icons.apple_rounded,
        accentColor: AppColors.gold,
        content: Text(
          'تعذر جلب الباقة (${package.title}) من أبل StoreKit حالياً.\n\nقد يستغرق تفعيل الباقات الجديدة على سيرفرات أبل من ساعة إلى ساعتين، وتأكد من اكتمال اتفاقية (Paid Applications) في App Store Connect.\n\nهل ترغب بالدفع فوراً عبر كي نت (KNET) بدلاً من ذلك؟',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          GoldButton(
            label: 'إلغاء',
            outlined: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: () => Navigator.pop(context),
          ),
          GoldButton(
            label: 'ادفع عبر كي نت',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: () {
              Navigator.pop(context);
              final auth = context.read<AuthCubit>().state;
              if (auth.userId != null) {
                _purchaseWithMyFatoorah(package, auth.userId!, auth.name);
              }
            },
          ),
        ],
      );
    }
  }

  /// نافذة اختيار وسيلة الدفع عند توفر كل من أبل وماي فاتورة
  Future<void> _showPaymentMethodSheet(
    CoinPackage package,
    String uid,
    String customerName,
  ) async {
    final appleProduct = _iap.products[package.id];
    final applePrice = appleProduct?.price ?? package.priceString;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F261B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.gold, width: 1.5),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'اختر وسيلة الدفع - ${package.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'المجموع: ${package.totalCoins} نقطة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 18),

                // خيار أبل ستور الرسمي
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _purchaseWithApple(package);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apple_rounded, size: 28, color: Colors.white),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Apple In-App Purchase',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'الدفع بـ Face ID / Touch ID ($applePrice)',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // خيار كي نت ماي فاتورة
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _purchaseWithMyFatoorah(package, uid, customerName);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3D2B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold.withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 26, color: AppColors.goldLight),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'كي نت (KNET) • فيزا • ماستركارد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'عبر بوابة ماي فاتورة (${package.priceString})',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// تنفيذ الشراء عبر بوابة ماي فاتورة
  Future<void> _purchaseWithMyFatoorah(
    CoinPackage package,
    String uid,
    String customerName,
  ) async {
    setState(() => _purchasingId = package.id);

    try {
      if (AppConfig.isMyFatoorahConfigured) {
        // جلب البريد المسجل للمستخدم إن وجد
        String? email;
        try {
          email = Supabase.instance.client.auth.currentUser?.email;
        } catch (_) {}

        // 1. إنشاء رابط فاتورة الدفع من ماي فاتورة
        final invRes = await MyFatoorahService.instance.createPaymentInvoice(
          kwdAmount: package.kwdAmount,
          customerName: customerName,
          userId: uid,
          packageId: package.id,
          customerEmail: email,
        );

        if (!invRes.isSuccess || invRes.paymentUrl == null) {
          if (mounted) {
            setState(() => _purchasingId = null);
            await showLuxuryDialog<void>(
              context: context,
              title: 'تعذر فتح بوابة الدفع',
              icon: Icons.error_outline_rounded,
              accentColor: AppColors.danger,
              content: Text(
                invRes.errorMessage ?? 'حدث خطأ أثناء التواصل مع ماي فاتورة',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                GoldButton(
                  label: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          }
          return;
        }

        // 2. فتح صفحة الدفع في متصفح آمن داخل التطبيق (تدعم KNET وأبل باي وفيزا)
        final uri = Uri.parse(invRes.paymentUrl!);
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);

        // 3. عند العودة: التحقق من نجاح الدفع مع ماي فاتورة
        if (!mounted) return;
        await _verifyPayment(package, invRes.invoiceId!);
      } else {
        // إذا لم يُضف العميل الـ API Token بعد، تشغيل وضع المحاكاة للتجربة
        await _simulatePurchase(package, uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchasingId = null);
        showSnack(context, 'حدث خطأ أثناء معالجة الطلب: $e');
      }
    }
  }

  /// التحقق من إتمام الفاتورة بعد عودة اللاعب من صفحة الدفع
  Future<void> _verifyPayment(CoinPackage package, String invoiceId) async {
    // إظهار نافذة جارٍ التحقق
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F261B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
        title: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.goldLight),
            ),
            SizedBox(width: 12),
            Text('التحقق من الدفع', style: TextStyle(color: AppColors.goldLight, fontSize: 16)),
          ],
        ),
        content: const Text(
          'جارٍ التأكد من إتمام العملية من بوابة ماي فاتورة...',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );

    // انتظار قصير للتأكد من وصول تحديث البوابة
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final status = await MyFatoorahService.instance.checkPaymentStatus(invoiceId);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // إغلاق نافذة التحقق

    if (status.isPaid) {
      await _creditAccount(package, invoiceId, status.paymentGateway);
    } else {
      setState(() => _purchasingId = null);
      showSnack(context, 'لم يتم استكمال عملية الدفع أو تم إلغاؤها.');
    }
  }

  /// محاكاة الشحن في بيئة التطوير (عند عدم توفر الـ API Token)
  Future<void> _simulatePurchase(CoinPackage package, String uid) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final simulatedId = 'MF_SIM_${DateTime.now().millisecondsSinceEpoch}';
    await _creditAccount(package, simulatedId, 'KNET (تجريبي)');
  }

  /// إضافة النقاط إلى حساب اللاعب في Supabase
  Future<void> _creditAccount(CoinPackage package, String invoiceId, String? gateway) async {
    final uid = context.read<AuthCubit>().state.userId!;
    if (AppConfig.isOnlineConfigured) {
      try {
        await Supabase.instance.client.rpc('credit_myfatoorah_purchase', params: {
          'p_user_id': uid,
          'p_coins': package.totalCoins,
          'p_invoice_id': invoiceId,
          'p_kwd_amount': package.kwdAmount,
          'p_package_id': package.id,
        });
      } catch (_) {
        // في حال عدم تشغيل دالة myfatoorah في SQL بعد، نجرب دالة الشحن العامة
        try {
          await Supabase.instance.client.rpc('credit_apple_purchase', params: {
            'p_user_id': uid,
            'p_coins': package.totalCoins,
            'p_order_id': invoiceId,
            'p_product_id': package.id,
          });
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _currentCoins += package.totalCoins;
      _purchasingId = null;
    });
    context.read<AuthCubit>().refreshCoins();

    SoundService.instance.play(Sfx.win);
    await showLuxuryDialog<void>(
      context: context,
      title: 'تم الشحن بنجاح!',
      icon: Icons.check_circle_rounded,
      accentColor: AppColors.goldLight,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.goldLight, size: 54),
          const SizedBox(height: 12),
          Text(
            'تمت إضافة +${package.totalCoins} نقطة إلى رصيدك.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المبلغ: ${package.priceString} • ${gateway ?? "ماي فاتورة"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        GoldButton(
          label: 'رائع',
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متجر النقاط'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'استعادة المشتريات',
            icon: const Icon(Icons.restore_rounded),
            onPressed: _restorePurchases,
          ),
          IconButton(
            tooltip: 'تحديث الرصيد',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBalance,
          ),
        ],
      ),
      body: FeltBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // كارت الرصيد الحالي
              _buildBalanceHeader(),
              const SizedBox(height: 12),

              // تنبيه الدخول كضيف
              if (context.watch<AuthCubit>().state.isGuest) ...[
                _buildGuestWarningBanner(),
                const SizedBox(height: 12),
              ],

              // بطاقة بوابة الدفع المعتمدة (MyFatoorah / KNET)
              _buildPaymentGatewayBanner(),
              const SizedBox(height: 14),

              // رسالة تنبيه عند نقص الرصيد المطلوب لغرفة معينة
              if (widget.requiredPoints != null &&
                  _currentCoins < widget.requiredPoints!) ...[
                _buildDeficitWarning(widget.requiredPoints!),
                const SizedBox(height: 18),
              ],

              const Text(
                'باقات النقاط (الدفع بالدينار الكويتي)',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),

              // قائمة الباقات
              for (final pkg in kCoinPackages) ...[
                _buildPackageCard(pkg),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 16),
              _buildSecurityFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3D2B), Color(0xFF0F261B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withAlpha(140), width: 1.3),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldLight, AppColors.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withAlpha(130),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFF261905),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رصيدك الحالي',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '$_currentCoins نقطة',
                        style: const TextStyle(
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGatewayBanner() {
    final hasMf = AppConfig.isMyFatoorahConfigured;
    final hasApple = _iap.isAvailable;
    final isSecured = hasMf || hasApple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isSecured ? const Color(0x33008444) : Colors.amber.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSecured ? const Color(0xFF00A859).withAlpha(140) : Colors.amber.withAlpha(120),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSecured ? Icons.verified_user_rounded : Icons.info_outline_rounded,
            color: isSecured ? const Color(0xFF4BE0A8) : Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طرق الدفع الرسمية المعتمدة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasApple
                      ? 'مدعوم رسميًا: متجر أبل (StoreKit) • كي نت (KNET) عبر ماي فاتورة.'
                      : (hasMf
                          ? 'بوابة ماي فاتورة: كي نت (KNET) • فيزا • ماستركارد (بالدينار الكويتي).'
                          : 'وضع التجربة والمحاكاة مفعّل. عند التشغيل على أجهزة أبل أو وضع Token ستعمل البوابات مباشرة.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33E67E22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE67E22).withAlpha(160)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined, color: Color(0xFFF39C12), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنت مسجل حالياً كـ (زائر / Guest)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'سجّل الدخول بحسابك لتتمكن من الشحن وحفظ النقاط في حسابك.',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            child: const Text(
              'دخول',
              style: TextStyle(
                color: AppColors.goldLight,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeficitWarning(int required) {
    final deficit = required - _currentCoins;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33E74C3C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE74C3C).withAlpha(160)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFF7675), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تحتاج إلى $deficit نقطة إضافية لدخول الغرفة (الرسم: $required).',
              style: const TextStyle(
                color: Color(0xFFFFD2D2),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(CoinPackage pkg) {
    final isBusy = _purchasingId == pkg.id;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pkg.isPopular
              ? [const Color(0xFF233B2E), const Color(0xFF13231B)]
              : [const Color(0xFF162534), const Color(0xFF0C1620)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pkg.isPopular ? AppColors.gold : Colors.white.withAlpha(45),
          width: pkg.isPopular ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // أيقونة الباقة
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: pkg.isPopular
                          ? AppColors.gold.withAlpha(120)
                          : Colors.white.withAlpha(30),
                    ),
                  ),
                  child: Icon(
                    pkg.icon,
                    color: pkg.isPopular ? AppColors.goldLight : Colors.white70,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // تفاصيل الباقة والفيش
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${pkg.coins} نقطة',
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            if (pkg.bonus > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71).withAlpha(40),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF2ECC71).withAlpha(140),
                                  ),
                                ),
                                child: Text(
                                  '+${pkg.bonus} هدية',
                                  style: const TextStyle(
                                    color: Color(0xFF58F29A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // زر الشراء بالدينار الكويتي
                ElevatedButton(
                  onPressed: isBusy ? null : () => _handlePurchase(pkg),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        pkg.isPopular ? AppColors.gold : const Color(0xFF2E4053),
                    foregroundColor:
                        pkg.isPopular ? const Color(0xFF1E1304) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          pkg.priceString,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // شارة الباقة المميزة
          if (pkg.badge != null)
            Positioned(
              top: -8,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4),
                  ],
                ),
                child: Text(
                  pkg.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_rounded, size: 14, color: Colors.white54),
              SizedBox(width: 6),
              Text(
                'دفع آمن ومعتمد عبر Apple StoreKit وماي فاتورة (KNET)',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'متوافق مع Apple In-App Purchase وشبكة المدفوعات الكويتية كي نت (KNET).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10.5),
        ),
      ],
    );
  }
}
