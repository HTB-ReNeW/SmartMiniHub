import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/mappers/facility_management_mapper.dart';
import 'package:storehub_mobile/widgets/rental_agreement_screen.dart';

void main() {
  final json = <String, dynamic>{
    'termsContentSnapshot': 'Điều khoản đã lưu của đơn thuê',
    'prohibitedItemsSnapshot': 'Danh mục cấm đã lưu',
    'termsVersion': 'v1',
    'termsAccepted': true,
    'prohibitedItemsAccepted': true,
    'termsAcceptedAt': '2026-11-03T10:30:00',
  };
  test('Customer and facility read the same stored agreement', () {
    final customer = MyUnitModel.fromJson(json).agreement;
    final facility = FacilityManagementMapper.contractFromJson(json).agreement;
    expect(customer.terms, facility.terms);
    expect(customer.prohibitedItems, facility.prohibitedItems);
    expect(customer.acceptedAt, facility.acceptedAt);
    expect(customer.termsAccepted, isTrue);
    expect(facility.prohibitedItemsAccepted, isTrue);
  });
  test('Customer and facility expose the same signed contract photos', () {
    final data = {
      ...json,
      'contractPhotos': ['https://example.invalid/signed.jpg']
    };
    final customer = MyUnitModel.fromJson(data).agreement;
    final facility = FacilityManagementMapper.contractFromJson(data).agreement;
    expect(customer.contractPhotos, ['https://example.invalid/signed.jpg']);
    expect(facility.contractPhotos, customer.contractPhotos);
  });
  testWidgets('Shows stored terms and acceptance for a paid booking',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RentalAgreementScreen(
            fields: const [('Mã đơn thuê', 'BK-PAID')],
            agreement: MyUnitModel.fromJson(json).agreement)));
    expect(find.text('BK-PAID'), findsOneWidget);
    expect(find.text('Đã đồng ý điều khoản thuê kho'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Điều khoản đã lưu của đơn thuê'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Điều khoản đã lưu của đơn thuê'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Legacy booking does not claim acceptance', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RentalAgreementScreen(
            fields: const [], agreement: MyUnitModel.fromJson({}).agreement)));
    expect(find.text('Chưa có dữ liệu xác nhận điều khoản'), findsOneWidget);
    expect(find.text('Đã đồng ý điều khoản thuê kho'), findsNothing);
  });
}
