import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test_build_game/bloc/auth_cubit.dart';
import 'package:test_build_game/core/theme.dart';
import 'package:test_build_game/data/myfatoorah_service.dart';
import 'package:test_build_game/ui/store_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyFatoorahService', () {
    test('createPaymentInvoice parses response accurately', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v2/ExecutePayment')) {
          return http.Response(
            jsonEncode({
              'IsSuccess': true,
              'Message': 'Invoice created successfully',
              'Data': {
                'InvoiceId': 987654,
                'PaymentURL': 'https://demo.myfatoorah.com/En/KWT/PayInvoice/Checkout?invoiceKey=test123',
              },
            }),
            200,
          );
        }
        return http.Response('{"IsSuccess": false}', 400);
      });

      final service = MyFatoorahService(client: mockClient);
      final res = await service.createPaymentInvoice(
        kwdAmount: 1.750,
        customerName: 'يوسف',
        userId: 'user-123',
        packageId: 'com.koutbo4.coins_5000',
      );

      expect(res.isSuccess, isTrue);
      expect(res.invoiceId, '987654');
      expect(res.paymentUrl, contains('invoiceKey=test123'));
    });

    test('checkPaymentStatus returns paid status', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v2/GetPaymentStatus')) {
          return http.Response(
            jsonEncode({
              'IsSuccess': true,
              'Data': {
                'InvoiceId': 987654,
                'InvoiceStatus': 'Paid',
                'InvoiceValue': 1.750,
                'InvoiceTransactions': [
                  {
                    'PaymentGateway': 'KNET',
                    'TransactionStatus': 'Succss',
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('{"IsSuccess": false}', 400);
      });

      final service = MyFatoorahService(client: mockClient);
      final status = await service.checkPaymentStatus('987654');
      expect(status.isPaid, isTrue);
      expect(status.invoiceStatus, 'Paid');
      expect(status.paymentGateway, 'KNET');
    });
  });

  group('StorePage layout', () {
    testWidgets('renders all KWD packages and balance cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(null),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: StorePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StorePage), findsOneWidget);
      expect(find.text('متجر النقاط'), findsOneWidget);
      expect(find.text('0.500 د.ك'), findsOneWidget);
      expect(find.text('1.750 د.ك'), findsOneWidget);
      expect(find.text('4.500 د.ك'), findsOneWidget);
      expect(find.text('12.000 د.ك'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
