import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/facility_model.dart';
import 'package:storehub_mobile/screens/customer/reservation/explore_screen.dart';
import 'package:storehub_mobile/services/catalog_api_service.dart';

class Catalog extends CatalogApiService {
  @override
  Future<List<FacilityModel>> getFacilitiesWithStats() async => [
        FacilityModel(
                id: 'f1',
                name: 'StoreHub District 7',
                address: '456 Nguyen Huu Tho',
                city: 'Ho Chi Minh City')
            .withUnitTypeStats([
          {'areaSqm': 9, 'basePricePerMonth': 2500000, 'availableUnitsCount': 2}
        ]),
        FacilityModel(
                id: 'f2',
                name: 'StoreHub Thu Duc',
                address: '789 Vo Van Ngan',
                city: 'Ho Chi Minh City')
            .withUnitTypeStats([
          {'areaSqm': 1, 'basePricePerMonth': 500000, 'availableUnitsCount': 3}
        ]),
      ];
}

void main() {
  testWidgets('Search, three filter sections, and removable region filter',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ExploreScreen(catalogService: Catalog())));
    await tester.pumpAndSettle();
    expect(find.text('StoreHub District 7'), findsOneWidget);
    expect(find.text('StoreHub Thu Duc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Bộ lọc tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Diện tích kho'), findsOneWidget);
    expect(find.text('Khu vực'), findsOneWidget);
    expect(find.text('Giá thuê hàng tháng'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên khu vực'), 'Quận 7');
    await tester.ensureVisible(find.text('Áp dụng bộ lọc'));
    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('StoreHub District 7'), findsOneWidget);
    expect(find.text('StoreHub Thu Duc'), findsNothing);
    final chip = find.ancestor(
        of: find.text('Quận 7'), matching: find.byType(InputChip));
    await tester
        .tap(find.descendant(of: chip, matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(find.text('StoreHub Thu Duc'), findsOneWidget);
    await tester.tap(find.byTooltip('Bộ lọc tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Diện tích từ'), '8');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Diện tích đến'), '4');
    await tester.ensureVisible(find.text('Áp dụng bộ lọc'));
    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Phải ≥ mức tối thiểu'), findsOneWidget);
    await tester.ensureVisible(find.text('Xóa tất cả'));
    await tester.tap(find.text('Xóa tất cả'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Giá từ'), '500.000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Giá đến'), '1.000.000');
    await tester.ensureVisible(find.text('Áp dụng bộ lọc'));
    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('StoreHub Thu Duc'), findsOneWidget);
    expect(find.text('StoreHub District 7'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
