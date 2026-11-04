import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/theme/app_theme.dart';
import 'package:storehub_mobile/models/facility_model.dart';
import 'package:storehub_mobile/screens/customer/reservation/explore_screen.dart';
import 'package:storehub_mobile/services/catalog_api_service.dart';

class ExploreApi extends CatalogApiService {
  @override
  Future<List<FacilityModel>> getFacilitiesWithStats() async => [
        FacilityModel(
                id: 'one',
                name: 'StoreHub District 1',
                address: '123 Nguyễn Huệ, Bến Nghé',
                city: 'Ho Chi Minh City')
            .withUnitTypeStats([
          {'areaSqm': 1, 'basePricePerMonth': 500000, 'availableUnitsCount': 1},
          {
            'areaSqm': 9,
            'basePricePerMonth': 2500000,
            'availableUnitsCount': 0
          },
        ])
      ];
}

Future<void> open(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: ExploreScreen(catalogService: ExploreApi())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone card and large text fit without overflow', (tester) async {
    await open(tester, scale: 1.4);
    expect(find.text('Khám phá cơ sở'), findsOneWidget);
    expect(find.text('StoreHub District 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('manual filters update card and reset draft on reopen',
      (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Bộ lọc tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Diện tích kho (m²)'), findsOneWidget);
    expect(find.text('Khu vực'), findsOneWidget);
    expect(find.text('Giá thuê hàng tháng'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('area-min')), '5');
    await tester.enterText(find.byKey(const ValueKey('rent-min')), '12');
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2.500.000'), findsOneWidget);
    expect(find.textContaining('Đã hết chỗ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Bộ lọc tìm kiếm'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('area-min')))
            .controller!
            .text,
        '5.0');
    await tester.tap(find.text('Xóa tất cả'));
    await tester.pump();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('area-min')))
            .controller!
            .text,
        isEmpty);
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('500.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reversed range stays open with validation', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Bộ lọc tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('area-min')), '9');
    await tester.enterText(find.byKey(const ValueKey('area-max')), '4');
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Phải lớn hơn hoặc bằng mức từ'), findsOneWidget);
    expect(find.byKey(const ValueKey('area-min')), findsOneWidget);
  });
}
