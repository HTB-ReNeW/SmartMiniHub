import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/screens/manager/refund_review_screen.dart';
import 'package:storehub_mobile/screens/manager/refund_detail_screen.dart';
import 'package:storehub_mobile/services/facility_ops_api_service.dart';

class ReviewApi extends FacilityOpsApiService {
  bool completed = false, failTransfer = false, failDetail = false;
  int writes = 0;
  String? reference, notes;
  final calls = <(String, int, int)>[];
  Map<String, dynamic> get row => {
        'id': 'refund-1',
        'bookingId': 'booking-1',
        'bookingCode': 'BK-89E13287',
        'originalTransactionId': 'TXN-123',
        'amount': 3050000,
        'status': completed ? 'COMPLETED' : 'AWAITING_BANK_TRANSFER',
        'dueAt': '2026-11-09T13:57:00',
        'bankCode': 'VietinBank',
        'bankAccountNumber': '012345678999',
        'bankAccountName': 'NGUYEN VAN AN',
        'transferReference': reference,
        'details': {
          'customerName': 'Nguyễn Văn An',
          'customerPhone': '0901234567',
          'customerEmail': 'customer@gmail.com',
          'facilityName': 'StoreHub Thu Duc',
          'unitCode': 'L-301',
          'unitType': 'Large',
          'refundKind': 'CANCELLATION',
          'reason': 'Hủy đơn trước khi nhận kho',
          'depositBefore': 500000,
          'depositRefund': 500000,
          'rentalRefund': 2500000,
          'serviceFeeRefund': 50000,
          'rentalServiceSplitKnown': true,
          'lateFeeDeduction': 0,
          'damageDeduction': 0,
          'cancellationDeduction': 0,
          'bookedAt': '2026-11-04T12:32:00',
          'requestedAt': '2026-11-04T13:57:00',
          'depositRefundPercent': 100,
          if (completed) 'completedAt': '2026-11-04T16:00:00',
          if (completed) 'confirmedByName': 'Facility 3',
          'transferNotes': notes,
          'termsAccepted': true,
          'prohibitedItemsAccepted': true,
          'termsContentSnapshot': 'Điều khoản đã chấp thuận',
          'prohibitedItemsSnapshot': 'Không lưu hàng cấm',
        }
      };
  @override
  Future<Map<String, dynamic>> getFacilityRefunds(String facilityId,
      {int page = 0, int size = 10, String filter = 'ALL'}) async {
    calls.add((filter, page, size));
    return {
      'content': [row],
      'totalElements': filter == 'COMPLETED'
          ? 1
          : filter == 'PENDING'
              ? 20
              : 21,
      'totalPages': filter == 'COMPLETED'
          ? 1
          : filter == 'PENDING'
              ? 2
              : 3,
      'allCount': 21,
      'pendingCount': completed ? 19 : 20,
      'completedCount': completed ? 2 : 1
    };
  }

  @override
  Future<Map<String, dynamic>> getFacilityRefundDetail(
      String facilityId, String refundId) async {
    if (failDetail) throw Exception('Không tải được dữ liệu');
    return row;
  }

  @override
  Future<void> confirmBankTransfer(String facilityId, String refundId,
      {required String transferReference, String? notes}) async {
    writes++;
    reference = transferReference;
    this.notes = notes;
    if (failTransfer) throw Exception('Chưa ghi nhận xác nhận');
    completed = true;
  }
}

Future<void> phone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list follows server filters and global counts beyond first page',
      (tester) async {
    final api = ReviewApi();
    await phone(tester, RefundReviewScreen(facilityId: 'f', service: api));
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Tất cả 21'), findsOneWidget);
    expect(find.text('012345678999'), findsNothing);
    await tester.tap(find.text('Chờ hoàn 20'));
    await tester.pumpAndSettle();
    expect(api.calls.last, ('PENDING', 0, 10));
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(api.calls.last, ('PENDING', 1, 10));
    await tester.tap(find.text('Đã hoàn 1'));
    await tester.pumpAndSettle();
    expect(api.calls.last, ('COMPLETED', 0, 10));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'detail displays real breakdown and confirms only with entered bank reference',
      (tester) async {
    final api = ReviewApi();
    await phone(tester, RefundReviewScreen(facilityId: 'f', service: api));
    await tester.tap(find.text('Xem chi tiết đối soát'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết hoàn tiền'), findsOneWidget);
    expect(find.text('Chi tiết đối soát'), findsOneWidget);
    expect(find.textContaining('2.500.000'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^50\.000')), findsOneWidget);
    expect(find.textContaining('500.000'), findsWidgets);
    await tester.tap(find.text('Xác nhận đã chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.text('VietinBank · 012345678999'), findsOneWidget);
    expect(find.text('NGUYEN VAN AN'), findsWidgets);
    await tester.tap(find.text('Xác nhận hoàn tất'));
    await tester.pumpAndSettle();
    expect(api.writes, 0);
    expect(find.text('Vui lòng nhập mã giao dịch ngân hàng'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('transfer-reference')), 'FT-REAL-123');
    await tester.enterText(find.byType(TextFormField).last, 'Đã chuyển đủ');
    await tester.tap(find.text('Xác nhận hoàn tất'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.reference, 'FT-REAL-123');
    expect(api.notes, 'Đã chuyển đủ');
    expect(find.text('Đã hoàn tiền'), findsWidgets);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đã hoàn tiền'));
    expect(button.onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Đã hoàn 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed confirmation retains entered reference for retry',
      (tester) async {
    final api = ReviewApi()..failTransfer = true;
    await phone(tester,
        RefundDetailScreen(facilityId: 'f', initial: api.row, service: api));
    await tester.tap(find.text('Xác nhận đã chuyển khoản'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('transfer-reference')), 'FT-RETRY-123');
    await tester.tap(find.text('Xác nhận hoàn tất'));
    await tester.pumpAndSettle();
    expect(api.completed, isFalse);
    await tester.tap(find.text('Xác nhận đã chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.text('FT-RETRY-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stale detail cannot authorize a transfer when refresh fails',
      (tester) async {
    final api = ReviewApi()..failDetail = true;
    await phone(tester,
        RefundDetailScreen(facilityId: 'f', initial: api.row, service: api));
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận đã chuyển khoản'));
    expect(button.onPressed, isNull);
    expect(api.writes, 0);
  });
  testWidgets('bank copy preserves leading zeroes', (tester) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final api = ReviewApi();
    await phone(tester,
        RefundDetailScreen(facilityId: 'f', initial: api.row, service: api));
    await tester.scrollUntilVisible(
        find.byTooltip('Sao chép số tài khoản'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Sao chép số tài khoản')),
        alignment: 0.2);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sao chép số tài khoản'));
    await tester.pumpAndSettle();
    expect(copied, '012345678999');
    expect(tester.takeException(), isNull);
  });
}
