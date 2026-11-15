import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// نتيجة إنشاء فاتورة دفع في ماي فاتورة
class MyFatoorahInvoiceResult {
  const MyFatoorahInvoiceResult({
    required this.isSuccess,
    this.invoiceId,
    this.paymentUrl,
    this.errorMessage,
  });

  final bool isSuccess;
  final String? invoiceId;
  final String? paymentUrl;
  final String? errorMessage;
}

/// نتيجة التحقق من حالة الدفع
class MyFatoorahPaymentStatus {
  const MyFatoorahPaymentStatus({
    required this.isSuccess,
    required this.isPaid,
    this.invoiceStatus,
    this.invoiceValue = 0.0,
    this.paymentGateway,
    this.errorMessage,
  });

  final bool isSuccess;
  final bool isPaid;
  final String? invoiceStatus;
  final double invoiceValue;
  final String? paymentGateway;
  final String? errorMessage;
}

/// خدمة ربط بوابة الدفع الكويتية ماي فاتورة (MyFatoorah)
/// تدعم كي نت (KNET)، فيزا، ماستركارد، وأبل باي بالدينار الكويتي (KWD).
class MyFatoorahService {
  MyFatoorahService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static MyFatoorahService instance = MyFatoorahService();

  String get _baseUrl => AppConfig.myFatoorahIsLive
      ? 'https://api.myfatoorah.com'
      : 'https://apitest.myfatoorah.com';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${AppConfig.myFatoorahToken.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// إنشاء رابط دفع لفاتورة جديدة بالدينار الكويتي
  /// [paymentMethodId]:
  ///  - 1 = كي نت (KNET) المباشر
  ///  - 2 = فيزا / ماستركارد المباشر
  ///  - 0 = صفحة ماي فاتورة الشاملة التي تضم جميع خيارات الدفع
  Future<MyFatoorahInvoiceResult> createPaymentInvoice({
    required double kwdAmount,
    required String customerName,
    required String userId,
    required String packageId,
    String? customerEmail,
    int paymentMethodId = 1,
  }) async {
    if (!AppConfig.isMyFatoorahConfigured) {
      return const MyFatoorahInvoiceResult(
        isSuccess: false,
        errorMessage: 'لم يتم إضافة مفتاح MyFatoorah API Token بعد في الإعدادات.',
      );
    }

    // إذا كان المطلوب عرض جميع طرق الدفع في صفحة الفاتورة، نستخدم SendPayment
    if (paymentMethodId == 0) {
      final url = Uri.parse('$_baseUrl/v2/SendPayment');
      final payload = <String, dynamic>{
        'CustomerName': customerName.trim().isEmpty ? 'لاعب كوت بو ٤' : customerName.trim(),
        'NotificationOption': 'LNK',
        'InvoiceValue': kwdAmount,
        'DisplayCurrencyIso': AppConfig.paymentCurrency,
        'CallBackUrl': 'https://koutbo4.app/payment/success',
        'ErrorUrl': 'https://koutbo4.app/payment/error',
        'CustomerReference': userId,
        'UserDefinedField': packageId,
        'Language': 'ar',
      };

      final email = customerEmail?.trim();
      if (email != null && email.isNotEmpty && email.contains('@') && email.contains('.')) {
        payload['CustomerEmail'] = email;
      }

      try {
        final res = await _http.post(url, headers: _headers, body: jsonEncode(payload));
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final isSuccess = json['IsSuccess'] == true;
        if (isSuccess && json['Data'] != null) {
          final data = json['Data'] as Map<String, dynamic>;
          final invoiceId = data['InvoiceId']?.toString();
          final paymentUrl = (data['InvoiceURL'] ?? data['PaymentURL']) as String?;
          return MyFatoorahInvoiceResult(
            isSuccess: true,
            invoiceId: invoiceId,
            paymentUrl: paymentUrl,
          );
        } else {
          final msg = json['Message']?.toString() ?? 'فشل إنشاء الفاتورة من بوابة الدفع';
          final valErrors = json['ValidationErrors'];
          final details = valErrors is List && valErrors.isNotEmpty
              ? valErrors.map((e) => e['Error'].toString()).join(' - ')
              : msg;
          return MyFatoorahInvoiceResult(isSuccess: false, errorMessage: details);
        }
      } catch (e) {
        return MyFatoorahInvoiceResult(
          isSuccess: false,
          errorMessage: 'تعذر الاتصال ببوابة ماي فاتورة: $e',
        );
      }
    }

    // الدفع المباشر عبر بوابة محددة (مثل كي نت = 1 أو فيزا = 2) عبر ExecutePayment
    final url = Uri.parse('$_baseUrl/v2/ExecutePayment');
    final payload = <String, dynamic>{
      'PaymentMethodId': paymentMethodId,
      'CustomerName': customerName.trim().isEmpty ? 'لاعب كوت بو ٤' : customerName.trim(),
      'DisplayCurrencyIso': AppConfig.paymentCurrency, // KWD
      'InvoiceValue': kwdAmount,
      'CallBackUrl': 'https://koutbo4.app/payment/success',
      'ErrorUrl': 'https://koutbo4.app/payment/error',
      'CustomerReference': userId,
      'UserDefinedField': packageId,
      'Language': 'ar',
    };

    // لا نرسل CustomerEmail إلا إذا كان إيميل صالح لتجنب رفض ماي فاتورة
    final email = customerEmail?.trim();
    if (email != null && email.isNotEmpty && email.contains('@') && email.contains('.')) {
      payload['CustomerEmail'] = email;
    }

    try {
      final res = await _http.post(url, headers: _headers, body: jsonEncode(payload));
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      final isSuccess = json['IsSuccess'] == true;
      if (isSuccess && json['Data'] != null) {
        final data = json['Data'] as Map<String, dynamic>;
        final invoiceId = data['InvoiceId']?.toString();
        final paymentUrl = data['PaymentURL'] as String?;
        return MyFatoorahInvoiceResult(
          isSuccess: true,
          invoiceId: invoiceId,
          paymentUrl: paymentUrl,
        );
      } else {
        final msg = json['Message']?.toString() ?? 'فشل إنشاء الفاتورة من بوابة الدفع';
        final valErrors = json['ValidationErrors'];
        final details = valErrors is List && valErrors.isNotEmpty
            ? valErrors.map((e) => e['Error'].toString()).join(' - ')
            : msg;
        return MyFatoorahInvoiceResult(
          isSuccess: false,
          errorMessage: details,
        );
      }
    } catch (e) {
      return MyFatoorahInvoiceResult(
        isSuccess: false,
        errorMessage: 'تعذر الاتصال ببوابة ماي فاتورة: $e',
      );
    }
  }

  /// التحقق من حالة الفاتورة والدفع في ماي فاتورة
  Future<MyFatoorahPaymentStatus> checkPaymentStatus(String invoiceId) async {
    if (!AppConfig.isMyFatoorahConfigured) {
      return const MyFatoorahPaymentStatus(
        isSuccess: false,
        isPaid: false,
        errorMessage: 'لم يتم إضافة مفتاح MyFatoorah API Token.',
      );
    }

    final url = Uri.parse('$_baseUrl/v2/GetPaymentStatus');
    final payload = {
      'Key': invoiceId,
      'KeyType': 'InvoiceId',
    };

    try {
      final res = await _http.post(url, headers: _headers, body: jsonEncode(payload));
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      final isSuccess = json['IsSuccess'] == true;
      if (isSuccess && json['Data'] != null) {
        final data = json['Data'] as Map<String, dynamic>;
        final status = (data['InvoiceStatus'] as String?) ?? 'Pending';
        final isPaid = status.toLowerCase() == 'paid';
        final val = (data['InvoiceValue'] as num?)?.toDouble() ?? 0.0;

        String? gateway;
        final txList = data['InvoiceTransactions'];
        if (txList is List && txList.isNotEmpty) {
          gateway = txList.first['PaymentGateway']?.toString();
        }

        return MyFatoorahPaymentStatus(
          isSuccess: true,
          isPaid: isPaid,
          invoiceStatus: status,
          invoiceValue: val,
          paymentGateway: gateway,
        );
      } else {
        final msg = json['Message']?.toString() ?? 'تعذر قراءة حالة الفاتورة';
        return MyFatoorahPaymentStatus(
          isSuccess: false,
          isPaid: false,
          errorMessage: msg,
        );
      }
    } catch (e) {
      return MyFatoorahPaymentStatus(
        isSuccess: false,
        isPaid: false,
        errorMessage: 'خطأ أثناء التحقق من الدفع: $e',
      );
    }
  }
}
