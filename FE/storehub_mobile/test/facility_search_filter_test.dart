import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/facility_model.dart';
import 'package:storehub_mobile/models/facility_search_filter.dart';

FacilityModel sample() => FacilityModel(
            id: 'f1',
            name: 'StoreHub District 7',
            address: '456 Nguyen Huu Tho, Tan Hung Ward',
            city: 'Ho Chi Minh City')
        .withUnitTypeStats([
      {
        'id': 'small',
        'areaSqm': 1,
        'basePricePerMonth': 500000,
        'availableUnitsCount': 3
      },
      {
        'id': 'large',
        'areaSqm': 9,
        'basePricePerMonth': 2500000,
        'availableUnitsCount': 2
      },
    ]);
void main() {
  test('Grouped VND prices preserve thousands', () {
    for (final value in ['500000', '500.000', '500,000', '500 000']) {
      expect(parseMonthlyRent(value), 500000);
    }
    expect(parseMonthlyRent('1.000.000'), 1000000);
    expect(parseMonthlyRent('500.5'), isNull);
  });

  test('Area must match an actual type, not a gap between sizes', () {
    expect(const FacilitySearchFilter(minArea: 4, maxArea: 5).apply(sample()),
        isNull);
  });
  test('Area and price must match the same storage type', () {
    expect(
        const FacilitySearchFilter(minArea: 8, maxPrice: 600000)
            .apply(sample()),
        isNull);
    final result = const FacilitySearchFilter(minArea: 8, maxPrice: 2500000)
        .apply(sample())!;
    expect(result.minPricePerMonth, 2500000);
    expect(result.minAreaSqm, 9);
    expect(result.availableUnits, 2);
  });
  test('Location supports Vietnamese accents and district aliases', () {
    expect(const FacilitySearchFilter(region: 'Quận 7').apply(sample()),
        isNotNull);
    expect(const FacilitySearchFilter(query: 'Nguyễn Hữu Thọ').apply(sample()),
        isNotNull);
    expect(
        const FacilitySearchFilter(region: 'Hà Nội').apply(sample()), isNull);
  });
  test('Unknown size and price do not pass active numeric filters', () {
    final facility =
        FacilityModel(id: 'empty', name: 'No details', address: '', city: '');
    expect(const FacilitySearchFilter().apply(facility), isNotNull);
    expect(const FacilitySearchFilter(minArea: 1).apply(facility), isNull);
  });
}
