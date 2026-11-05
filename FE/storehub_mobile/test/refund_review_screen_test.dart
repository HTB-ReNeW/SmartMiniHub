import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/screens/manager/refund_review_screen.dart';
import 'package:storehub_mobile/services/facility_ops_api_service.dart';

class RefundApi extends FacilityOpsApiService {
  final String status;
  RefundApi(this.status);
  @override
  Future<Map<String, dynamic>> getFacilityRefunds(String facilityId,
          {int page = 0, int size = 10, String filter = 'ALL'}) async =>
      {
        'content': [
          {
            'id': 'refund-1',
            'bookingCode': 'BK-CANCELLED',
            'status': status,
            'amount': 500000
          }
        ],
        'totalElements': 1,
        'totalPages': 1,
      };
}

void main() {
  for (final status in [
    'REJECTED',
    'NEEDS_REVIEW',
    'SENDING',
    'AWAITING_CONFIRMATION',
    'AWAITING_BANK_TRANSFER',
    'MISSING_METADATA'
  ]) {
    testWidgets('Refund $status remains visible with app button theme',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: RefundReviewScreen(
              facilityId: 'facility-1', service: RefundApi(status))));
      await tester.pumpAndSettle();
      expect(find.text('BK-CANCELLED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
