import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/return_settlement.dart';
import 'package:storehub_mobile/widgets/return_settlement_card.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/customer/my_units/contract_operation_dialog.dart';

void main() {
  testWidgets('full return dialog fits a small phone with the settlement table',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final unit = MyUnitModel.fromJson({
      'status': 'ACTIVE',
      'unitCode': 'S-101',
      'endDate': '2026-11-01',
      'depositPaid': 500000,
      'returnSettlement': {
        'endDate': '2026-11-01',
        'returnAt': '2026-11-04T15:00:00',
        'overdueDays': 3,
        'chargeableDays': 2,
        'graceDays': 1,
        'dailyLateFee': 50000,
        'totalLateFee': 100000,
        'lateFeeDeduction': 100000,
        'depositBefore': 500000,
        'depositRefund': 400000,
        'additionalPayment': 0,
        'finalized': false
      }
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => ContractOperationDialog(
                            unit: unit, isExtension: false)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Số ngày trễ'), findsOneWidget);
    expect(find.textContaining('400.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('explains 1 Nov to 4 Nov, grace, fee deduction and net deposit',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quote = ReturnSettlement.fromJson({
      'endDate': '2026-11-01',
      'returnAt': '2026-11-04T15:00:00',
      'overdueDays': 3,
      'graceDays': 1,
      'chargeableDays': 2,
      'dailyLateFee': 50000,
      'totalLateFee': 100000,
      'lateFeeAlreadyPaid': 0,
      'depositBefore': 500000,
      'lateFeeDeduction': 100000,
      'damageDeduction': 0,
      'depositRefund': 400000,
      'additionalPayment': 0,
      'finalized': false,
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ReturnSettlementCard(settlement: quote))))));
    expect(find.text('01/11/2026'), findsOneWidget);
    expect(find.text('04/11/2026'), findsOneWidget);
    expect(find.text('3 ngày'), findsOneWidget);
    expect(find.text('2 ngày'), findsOneWidget);
    expect(find.text('1 ngày'), findsOneWidget);
    expect(find.textContaining('400.000'), findsOneWidget);
    expect(find.text('Trừ phí trễ vào cọc'), findsOneWidget);
    expect(find.text('Phần phải trả thêm'), findsOneWidget);
    expect(find.textContaining('100%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
