import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/widgets/facility_contact_card.dart';

void main() {
  testWidgets('official contact remains readable on small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final unit = MyUnitModel.fromJson({
      'facilityManagerName': 'Nguyễn Văn Quản Lý',
      'facilityContactPhone': '0901234567',
      'facilityContactEmail': 'facility.with.a.long.email@storehub.test',
    });
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: FacilityContactCard(
                    managerName: unit.facilityManagerName,
                    phone: unit.facilityContactPhone,
                    email: unit.facilityContactEmail)))));
    expect(find.text('Quản lý: Nguyễn Văn Quản Lý'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(
        find.text('facility.with.a.long.email@storehub.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing contact has an explicit placeholder', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FacilityContactCard())));
    expect(find.text('Cơ sở chưa cập nhật số điện thoại hoặc email liên hệ.'),
        findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}
