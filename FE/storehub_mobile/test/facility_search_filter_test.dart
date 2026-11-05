import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/facility_model.dart';
import 'package:storehub_mobile/models/facility_search_filter.dart';

void main() {
  final facility = FacilityModel(
    id: 'one',
    name: 'StoreHub District 1',
    address: '123 Nguyễn Huệ',
    city: 'Ho Chi Minh City',
    airConditioned24h: true,
  ).withUnitTypeStats([
    {'areaSqm': 1, 'basePricePerMonth': 500000, 'availableUnitsCount': 1},
    {'areaSqm': 4, 'basePricePerMonth': 1200000, 'availableUnitsCount': 2},
    {'areaSqm': 9, 'basePricePerMonth': 2500000, 'availableUnitsCount': 0},
  ]);

  test('rent accepts whole VND and consistent thousands separators', () {
    for (final value in ['500000', '500.000', '500,000', '500 000']) {
      expect(parseMonthlyRent(value), 500000);
    }
    for (final value in ['12.5', '-1', '1e6', '1.200,000', '']) {
      expect(parseMonthlyRent(value), isNull);
    }
    expect(parseStorageArea('4,5'), 4.5);
  });
  test('area and rent must match the same physical unit type', () {
    expect(
        const FacilitySearchFilter(minArea: 5, maxRent: 600000).apply(facility),
        isNull);
    expect(const FacilitySearchFilter(minArea: 5, maxArea: 8).apply(facility),
        isNull);
  });
  test('filtered card statistics describe only matching types', () {
    final result =
        const FacilitySearchFilter(minArea: 4, minRent: 12).apply(facility)!;
    expect(result.minPricePerMonth, 1200000);
    expect(result.availableUnits, 2);
    expect(result.minAreaSqm, 4);
    expect(result.maxAreaSqm, 9);
    expect(result.airConditioned24h, isTrue);
    final soldOut = const FacilitySearchFilter(minArea: 5).apply(facility)!;
    expect(soldOut.availableUnits, 0);
    expect(soldOut.minPricePerMonth, 2500000);
  });
  test('region supports Vietnamese, district aliases and exact numbers', () {
    expect(const FacilitySearchFilter(region: 'Quận 1, TP HCM').apply(facility),
        isNotNull);
    expect(const FacilitySearchFilter().apply(facility, query: 'nguyen hu'),
        isNotNull);
    final district10 = FacilityModel(
        id: 'ten',
        name: 'District 10',
        address: '123 Nguyễn Huệ',
        city: 'Ho Chi Minh City');
    expect(
        const FacilitySearchFilter(region: 'Quận 1').apply(district10), isNull);
  });
  test('unknown stats cannot satisfy numeric filters; inactive excluded', () {
    final unknown = FacilityModel(id: 'x', name: 'X', address: 'Y', city: 'Z');
    expect(const FacilitySearchFilter(minRent: 0).apply(unknown), isNull);
    expect(
        const FacilitySearchFilter().apply(FacilityModel(
            id: 'x', name: 'X', address: 'Y', city: 'Z', status: 'INACTIVE')),
        isNull);
  });
}
