import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/mappers/facility_operations_mapper.dart';
import 'package:storehub_mobile/models/checkout_schedule_window.dart';
import 'package:storehub_mobile/models/facility_management_models.dart';
import 'package:storehub_mobile/models/facility_operations_models.dart';
import 'package:storehub_mobile/screens/manager/appointment_assignment_screen.dart';
import 'package:storehub_mobile/services/facility_ops_api_service.dart';

class AssignmentApi extends FacilityOpsApiService {
  final dates = <DateTime>[];
  final bool weekData;
  String? assigned = 'staff-a';
  int writes = 0;
  String? changedBooking, changedStaff;
  AssignmentApi({this.weekData = false});

  @override
  Future<List<FacilityStaffModel>> getFacilityStaff(String facilityId) async =>
      const [
        FacilityStaffModel(
            id: 'staff-a',
            fullName: 'Staff A',
            email: 'staff.a@storehub.test',
            role: 'STAFF'),
        FacilityStaffModel(
            id: 'staff-b',
            fullName: 'Staff B',
            email: 'staff.b@storehub.test',
            role: 'STAFF'),
      ];

  DailyScheduleModel item(String id, DateTime time) =>
      FacilityOperationsMapper.dailyScheduleFromJson({
        'bookingId': id,
        'bookingCode': 'BK-$id',
        'customerName': 'Nguyễn Văn An',
        'customerEmail': 'customer.with.a.long.email@storehub.test',
        'customerPhone': '0901234567',
        'unitCode': 'S-101',
        'type': 'Small',
        'dimensions': '1m x 1m x 2m',
        'floorLevel': 'Tầng 2',
        'scheduleType': 'CHECK_OUT',
        'scheduledTime': time.toIso8601String(),
        'startDate': '2026-10-01',
        'endDate': '2026-11-04',
        'notes': 'Gọi trước 15 phút',
        'bookingStatus': 'ACTIVE',
        'assignedStaffId': assigned,
        'assignedStaffName': assigned == null ? null : 'Staff A',
      });

  @override
  Future<List<DailyScheduleModel>> getDailySchedule(
      {required String facilityId, required DateTime date}) async {
    dates.add(date);
    if (!weekData) {
      return [item('one', DateTime(date.year, date.month, date.day, 10))];
    }
    final now = CheckoutScheduleWindow.vietnamNow();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    // The daily endpoint repeats unresolved appointments; the weekly UI must deduplicate and bound dates.
    return [
      item('monday', monday.add(const Duration(hours: 10))),
      item('sunday', monday.add(const Duration(days: 6, hours: 15))),
      item('previous-week', monday.subtract(const Duration(days: 1)))
    ];
  }

  @override
  Future<void> assignAppointment(
      {required String facilityId,
      required DailyScheduleModel appointment,
      String? staffId}) async {
    writes++;
    changedBooking = appointment.bookingId;
    changedStaff = staffId;
    assigned = staffId;
  }
}

Future<void> showScreen(WidgetTester tester, AssignmentApi api) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppointmentAssignmentScreen(facilityId: 'facility', service: api)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Selected day chips remain readable with the real application theme',
      (tester) async {
    await showScreen(tester, AssignmentApi());
    for (final label in ['Ngày mai', 'Hôm nay', 'Tuần này']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final chip =
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
      expect(chip.selected, isTrue);
      expect((chip.label as Text).style!.color, Colors.white);
      final contrast = (Colors.white.computeLuminance() + .05) /
          (chip.selectedColor!.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'This week loads seven dates and deduplicates unresolved appointments',
      (tester) async {
    final api = AssignmentApi(weekData: true);
    await showScreen(tester, api);
    api.dates.clear();
    await tester.tap(find.text('Tuần này'));
    await tester.pumpAndSettle();
    expect(api.dates.length, 7);
    expect(api.dates.map((d) => d.weekday).toSet().length, 7);
    expect(find.text('2 lịch hẹn'), findsOneWidget);
    expect(find.textContaining('BK-previous-week'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Card shows contact, unit, contract and notes without overflow on narrow screens',
      (tester) async {
    await showScreen(tester, AssignmentApi());
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(
        find.text('customer.with.a.long.email@storehub.test'), findsOneWidget);
    expect(find.textContaining('1m x 1m x 2m'), findsOneWidget);
    expect(find.textContaining('Tầng 2'), findsOneWidget);
    expect(find.textContaining('01/10/2026'), findsOneWidget);
    expect(find.text('Ghi chú: Gọi trước 15 phút'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final remove in [false, true]) {
    testWidgets('Assignment persists and refreshes, remove = $remove',
        (tester) async {
      final api = AssignmentApi();
      await showScreen(tester, api);
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.text('staff.b@storehub.test'), findsOneWidget);
      await tester.tap(find.text(remove ? 'Chưa phân công' : 'Staff B').last);
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(api.changedBooking, 'one');
      expect(api.changedStaff, remove ? isNull : 'staff-b');
      expect(
          find.text(remove
              ? 'Đã bỏ phân công nhân viên.'
              : 'Đã cập nhật nhân viên phụ trách.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
