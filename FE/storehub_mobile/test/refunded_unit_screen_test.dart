import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/screens/customer/my_units/my_rented_units_screen.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';

class UnitApi extends StorageApiService {
  final bool completed;
  UnitApi(this.completed);
  @override
  Future<List<dynamic>> getMyRentedUnits() async => [];
  @override
  Future<List<dynamic>> getAwaitingHandover() async => [
        {
          'bookingId': 'b1',
          'bookingCode': 'BK-CANCELLED',
          'unitCode': 'A-101',
          'status': 'CANCELLED',
          'refundCompleted': completed,
          'facilityName': 'StoreHub',
          'depositPaid': 0,
        }
      ];
}

void main() {
  for (final completed in [true, false]) {
    testWidgets('Refund completion $completed controls status and actions',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MyRentedUnitsScreen(storageService: UnitApi(completed))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chờ nhận (${completed ? 0 : 1})'));
      await tester.pumpAndSettle();
      if (completed) {
        expect(find.text('Đã hoàn tiền'), findsNothing);
        expect(find.text('Mở khóa'), findsNothing);
        expect(find.text('Quản lý'), findsNothing);
        expect(find.text('Hợp đồng & Cam kết'), findsNothing);
        expect(find.text('StoreHub'), findsNothing);
        expect(find.text('Khóa thông minh ngăn kho'), findsNothing);
      } else {
        expect(find.text('Đã gửi yêu cầu hủy'), findsOneWidget);
        expect(find.text('Mở khóa'), findsOneWidget);
        expect(find.text('Quản lý'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
