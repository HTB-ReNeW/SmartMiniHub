import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/customer/my_units/my_rented_units_screen.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';

class ReturnApi extends StorageApiService {
  final bool returned;
  ReturnApi(this.returned);
  @override
  Future<List<dynamic>> getMyRentedUnits() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return [
      {
        'bookingId': 'b-return',
        'bookingCode': 'BK-RETURN',
        'status': returned ? 'COMPLETED' : 'ACTIVE',
        'unitCode': 'S-101',
        'facilityName': 'StoreHub',
        'unitAssignmentConfirmed': true,
        'endDate':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'overdueDetectedAt': '2020-01-01',
        'overdue': true,
        'overdueFeeOutstanding': 1500000,
        if (returned) 'returnTime': now.toIso8601String(),
      }
    ];
  }

  @override
  Future<List<dynamic>> getAwaitingHandover() async => [];
}

void main() {
  for (final returned in [false, true]) {
    testWidgets('Return UI, physical return completed = $returned',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MyRentedUnitsScreen(storageService: ReturnApi(returned))));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán phí trễ hạn'), findsNothing);
      if (returned) {
        expect(find.text('Đã trả kho'), findsNWidgets(2));
        expect(find.text('Thanh toán phần còn thiếu'), findsOneWidget);
        final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đã trả kho'));
        expect(button.onPressed, isNull);
        expect(find.text('Mở khóa'), findsNothing);
        expect(find.text('Quản lý'), findsNothing);
      } else {
        expect(find.text('Trả kho'), findsOneWidget);
        expect(find.text('Quá hạn'), findsNothing);
        expect(find.textContaining('Hợp đồng đã quá hạn'), findsNothing);
        expect(find.textContaining('1.500.000'), findsNothing);
        await tester.tap(find.text('Quản lý'));
        await tester.pumpAndSettle();
        expect(find.text('Thanh toán phí trễ hạn'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('completed return has fixed settlement and no renewed access', () {
    final unit = MyUnitModel.fromJson({
      'status': 'COMPLETED',
      'returnTime': '2026-11-04T15:00:00',
      'endDate': '2026-11-01',
      'overdueFeeOutstanding': 150000,
      'activeAccess': false
    });
    expect(unit.isReturnSettlement, isTrue);
    expect(unit.overdue, isFalse);
    expect(unit.hasActiveAccess, isFalse);
  });
}
