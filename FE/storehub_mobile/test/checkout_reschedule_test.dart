import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/checkout_schedule_window.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/customer/my_units/contract_operation_dialog.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';
import 'package:storehub_mobile/widgets/rental_policy_terms.dart';

class CheckoutApi extends StorageApiService {
  int calls = 0;
  DateTime? time;
  String? bank, number, name, note;
  @override
  Future<Map<String, dynamic>> checkoutRental(
      String bookingId, DateTime scheduledReturnTime,
      {String? notes,
      String? bankCode,
      String? bankAccountNumber,
      String? bankAccountName}) async {
    calls++;
    time = scheduledReturnTime;
    bank = bankCode;
    number = bankAccountNumber;
    name = bankAccountName;
    note = notes;
    return {
      'status': 'ACTIVE',
      'scheduledReturnTime': scheduledReturnTime.toIso8601String(),
      'message': 'Đã cập nhật'
    };
  }
}

void main() {
  test(
      'Return window caps notice at expiry and permits only today/tomorrow when overdue',
      () {
    final now = DateTime(2026, 11, 4, 10);
    var window =
        CheckoutScheduleWindow.forRental(DateTime(2026, 11, 5), 3, now);
    expect(window.earliest, DateTime(2026, 11, 5));
    expect(window.latest, DateTime(2026, 11, 5));
    expect(window.validate(DateTime(2026, 11, 6, 10), now, '08:30', '19:30'),
        isNotNull);
    window = CheckoutScheduleWindow.forRental(DateTime(2026, 10, 4), 3, now);
    expect(window.earliest, DateTime(2026, 11, 4));
    expect(window.latest, DateTime(2026, 11, 5));
    expect(
        window.validate(DateTime(2026, 11, 5, 19, 30), now, '08:30', '19:30'),
        isNull);
    expect(
        window.validate(DateTime(2026, 11, 5, 19, 31), now, '08:30', '19:30'),
        isNotNull);
    expect(window.validate(DateTime(2026, 11, 4, 9), now, '08:30', '19:30'),
        isNotNull);
  });

  for (final past in [false, true]) {
    testWidgets(
        'Prefills all saved checkout details and rejects past appointment: $past',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = CheckoutScheduleWindow.vietnamNow();
      final time =
          DateTime(now.year, now.month, now.day + (past ? -1 : 1), 10, 30);
      final unit = MyUnitModel.fromJson({
        'bookingId': 'b1',
        'bookingCode': 'BK-RETURN',
        'status': 'ACTIVE',
        'endDate': now
            .subtract(const Duration(days: 2))
            .toIso8601String()
            .substring(0, 10),
        'scheduledReturnTime': time.toIso8601String(),
        'refundBankCode': 'VCB',
        'refundAccountNumber': '0012345678',
        'refundAccountName': 'NGUYEN VAN AN',
        'checkoutNotes': 'Gọi trước 15 phút',
        'rentalPolicy': {'returnNoticeDays': 3, 'refundSlaDays': 2},
      });
      final api = CheckoutApi();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ContractOperationDialog(
                  unit: unit, isExtension: false, storageService: api))));
      await tester.pumpAndSettle();
      expect(find.text('Đổi lịch trả kho'), findsOneWidget);
      final values = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text)
          .toList();
      expect(
          values,
          containsAll(
              ['VCB', '0012345678', 'NGUYEN VAN AN', 'Gọi trước 15 phút']));
      await tester.tap(find.text('Cập nhật lịch trả kho'));
      await tester.pumpAndSettle();
      if (past) {
        expect(api.calls, 0);
        expect(find.textContaining('Lịch hẹn đã qua.'), findsWidgets);
      } else {
        expect(api.calls, 1);
        expect(api.time, time);
        expect(api.number, '0012345678');
        expect(api.bank, 'VCB');
        expect(api.name, 'NGUYEN VAN AN');
        expect(api.note, 'Gọi trước 15 phút');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Contract shows booked overdue thresholds and separate refund anchors',
      (tester) async {
    final unit = MyUnitModel.fromJson({
      'endDate': '2026-11-04',
      'rentalPolicy': {
        'dailyLateFee': 70000,
        'overdueGraceDays': 2,
        'overdueAccessDisableDays': 4,
        'overdueSealingDays': 8,
        'refundSlaDays': 3,
      }
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RentalPolicyTerms(
                    policy: unit.agreement.policy,
                    endDate: unit.agreement.endDate)))));
    expect(find.textContaining('70.000'), findsOneWidget);
    expect(find.textContaining('07/11/2026'), findsOneWidget);
    expect(find.textContaining('PIN từ ngày quá hạn thứ 4'), findsOneWidget);
    expect(find.textContaining('quá hạn thứ 8'), findsOneWidget);
    expect(find.textContaining('3 ngày kể từ khi nhân viên'), findsOneWidget);
    expect(find.textContaining('3 ngày kể từ khi hệ thống'), findsOneWidget);
    expect(
        find.textContaining('không phải thời hạn chuyển tiền'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
