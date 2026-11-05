import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/facility_management_models.dart';
import 'package:storehub_mobile/screens/operations/facility_edit_screen.dart';
import 'package:storehub_mobile/services/admin_api_service.dart';
import 'package:storehub_mobile/services/facility_admin_api_service.dart';
import 'package:storehub_mobile/services/facility_ops_api_service.dart';

class MockAdminApiService extends AdminApiService {
  @override
  Future<List<dynamic>> getUsers() async {
    return [
      {
        'id': 'u1',
        'fullName': 'Nguyễn Quản Lý 1',
        'email': 'mgr1@storehub.com',
        'username': 'mgr1',
        'roleName': 'FACILITY_MANAGER',
        'facilityId': null,
      },
      {'id': 'staff', 'fullName': 'Staff hidden', 'roleName': 'STAFF'},
      {
        'id': 'u2',
        'fullName': 'Trần Quản Lý 2',
        'email': 'mgr2@storehub.com',
        'username': 'mgr2',
        'roleName': 'FACILITY_MANAGER',
        'facilityId': null,
      },
    ];
  }
}

class MockFacilityAdminApiService extends FacilityAdminApiService {
  @override
  Future<List<dynamic>> getFacilities({String? search}) async {
    return [];
  }
}

class MockFacilityOpsApiService extends FacilityOpsApiService {
  @override
  Future<List<FacilityStaffModel>> getFacilityManagers(
      String facilityId) async {
    return [];
  }
}

void main() {
  testWidgets(
      'FacilityManagerAssignmentSheet renders with AppTheme without BoxConstraints infinite width error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => FacilityManagerAssignmentSheet(
                    facilityId: 'f1',
                    facilityName: 'StoreHub Thu Duc',
                    currentManagerIds: const {},
                    adminApiService: MockAdminApiService(),
                    facilityService: MockFacilityAdminApiService(),
                    opsService: MockFacilityOpsApiService(),
                    onManagerAssigned: () async {},
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    // Tap to open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify sheet title is rendered
    expect(find.text('Gán quản lý cơ sở'), findsOneWidget);

    // Verify users are loaded and rendered
    expect(find.text('Nguyễn Quản Lý 1'), findsOneWidget);
    expect(find.text('Trần Quản Lý 2'), findsOneWidget);

    // Verify the "Gán" action buttons are rendered
    expect(find.text('Gán'), findsNWidgets(2));

    expect(find.text('Staff hidden'), findsNothing);
    expect(find.textContaining('Tất cả tài khoản'), findsNothing);

    // Verify NO layout exceptions occurred!
    expect(tester.takeException(), isNull);
  });
}
