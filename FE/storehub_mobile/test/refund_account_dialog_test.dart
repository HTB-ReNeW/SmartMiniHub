import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/screens/customer/my_units/refund_account_dialog.dart';

Future<void> open(WidgetTester tester,
    Future<void> Function(Map<String, String>) submit) async {
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => RefundAccountDialog(onSubmit: submit)),
                  child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), ' Vietcombank ');
  await tester.enterText(find.byType(TextFormField).at(1), '0012345678');
  await tester.enterText(find.byType(TextFormField).at(2), ' NGUYEN VAN AN ');
}

void main() {
  testWidgets('Rejects missing bank details without cancelling booking',
      (tester) async {
    int requests = 0;
    await open(tester, (_) async {
      requests++;
    });
    await tester.tap(find.text('Gửi yêu cầu hủy & hoàn tiền'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Vui lòng nhập ngân hàng'), findsOneWidget);
    expect(find.text('Vui lòng nhập tên chủ tài khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Submits exact beneficiary and keeps leading zeroes',
      (tester) async {
    Map<String, String>? sent;
    await open(tester, (data) async {
      sent = data;
    });
    await fill(tester);
    await tester.tap(find.text('Gửi yêu cầu hủy & hoàn tiền'));
    await tester.pumpAndSettle();
    expect(sent, {
      'bankCode': 'Vietcombank',
      'bankAccountNumber': '0012345678',
      'bankAccountName': 'NGUYEN VAN AN'
    });
    expect(find.byType(RefundAccountDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed submission retains entered account for retry',
      (tester) async {
    await open(tester, (_) async {
      throw Exception('Không thể kết nối');
    });
    await fill(tester);
    await tester.tap(find.text('Gửi yêu cầu hủy & hoàn tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể kết nối'), findsOneWidget);
    expect(find.text('0012345678'), findsOneWidget);
    expect(find.byType(RefundAccountDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
