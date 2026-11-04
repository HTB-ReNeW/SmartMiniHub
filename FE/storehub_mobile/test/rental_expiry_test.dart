import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/customer/my_units/my_rented_units_screen.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';

class ExpiredUnitApi extends StorageApiService {
  final bool scheduled;
  ExpiredUnitApi({this.scheduled = false});

  @override
  Future<List<dynamic>> getMyRentedUnits() async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    return [
      {
        'bookingId': 'expired-booking',
        'bookingCode': 'BK-EXPIRED',
        'unitCode': 'S-101',
        'facilityName': 'StoreHub',
        'status': 'ACTIVE',
        'endDate': today
            .subtract(const Duration(days: 2))
            .toIso8601String()
            .substring(0, 10),
        // Reproduce an old API which has not run its overdue job yet.
        'overdue': false,
        'overdueDays': 0,
        'overdueFeeOutstanding': 0,
        'activeAccess': true,
        if (scheduled)
          'scheduledReturnTime':
              today.add(const Duration(days: 1)).toIso8601String(),
      }
    ];
  }

  @override
  Future<List<dynamic>> getAwaitingHandover() async => [];
}

void main() {
  test(
      'Vietnam midnight determines expiry rather than UTC or a pending extension',
      () {
    final unit = MyUnitModel.fromJson({
      'status': 'ACTIVE',
      'endDate': '2026-11-03',
      'overdue': false,
      'hasPendingExtension': true,
      'pendingNewEndDate': '2026-12-03',
    });
    expect(unit.overdueDaysAt(DateTime.utc(2026, 11, 3, 16, 59)), 0);
    expect(unit.overdueDaysAt(DateTime.utc(2026, 11, 3, 17)), 1);
    expect(unit.overdueDaysAt(DateTime.utc(2026, 11, 4, 17)), 2);
    for (final status in ['CONFIRMED', 'CANCELLED', 'COMPLETED']) {
      final inactive = MyUnitModel.fromJson(
          {'status': status, 'endDate': '2026-11-03', 'overdue': true});
      expect(inactive.overdue, isFalse);
      expect(inactive.overdueDaysAt(DateTime.utc(2026, 11, 5)), 0);
    }
  });

  for (final scheduled in [false, true]) {
    testWidgets('Expired unit warns immediately, scheduled return = $scheduled',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MyRentedUnitsScreen(
            storageService: ExpiredUnitApi(scheduled: scheduled)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(
          find.textContaining('Hợp đồng đã quá hạn 2 ngày.'), findsOneWidget);
      if (scheduled) {
        expect(
            find.textContaining('Bạn đã gửi yêu cầu trả kho.'), findsOneWidget);
        expect(
            find.widgetWithText(TextButton, 'Yêu cầu trả kho'), findsNothing);
      } else {
        expect(
            find.textContaining(
                'Vui lòng gia hạn thuê hoặc gửi yêu cầu trả kho.'),
            findsOneWidget);
        expect(
            find.widgetWithText(TextButton, 'Yêu cầu trả kho'), findsOneWidget);
      }
      expect(find.textContaining('Vui lòng thanh toán phí trễ hạn trước'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
