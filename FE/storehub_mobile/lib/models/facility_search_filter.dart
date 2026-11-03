import 'facility_model.dart';

String normalizeFacilitySearch(String input) {
  var text = input.trim().toLowerCase();
  const groups = [
    'àáạảãâầấậẩẫăằắặẳẵ',
    'èéẹẻẽêềếệểễ',
    'ìíịỉĩ',
    'òóọỏõôồốộổỗơờớợởỡ',
    'ùúụủũưừứựửữ',
    'ỳýỵỷỹ',
    'đ'
  ];
  const plain = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
  for (var i = 0; i < groups.length; i++) {
    for (final rune in groups[i].runes) {
      text = text.replaceAll(String.fromCharCode(rune), plain[i]);
    }
  }
  text = text.replaceAll(RegExp(r'district\s*'), 'quan ');
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

/// Accept plain or thousands-grouped VND, without treating separators as decimals.
double? parseMonthlyRent(String input) {
  final value = input
      .trim()
      .replaceAll('\u00a0', ' ')
      .replaceFirst(RegExp(r'\s*(?:đ|₫|vnd)$', caseSensitive: false), '')
      .trim();
  if (!RegExp(r'^\d+$').hasMatch(value) &&
      !RegExp(r'^\d{1,3}([., ])\d{3}(?:\1\d{3})*$').hasMatch(value)) {
    return null;
  }
  final amount = double.tryParse(value.replaceAll(RegExp(r'[., ]'), ''));
  return amount != null && amount.isFinite ? amount : null;
}

class FacilitySearchFilter {
  final String query, region;
  final double? minArea, maxArea, minPrice, maxPrice;
  final bool airConditioned;
  const FacilitySearchFilter(
      {this.query = '',
      this.region = '',
      this.minArea,
      this.maxArea,
      this.minPrice,
      this.maxPrice,
      this.airConditioned = false});

  FacilityModel? apply(FacilityModel facility) {
    final location =
        normalizeFacilitySearch('${facility.name} ${facility.fullAddress}');
    if (!facility.isBookable ||
        !location.contains(normalizeFacilitySearch(query)) ||
        !location.contains(normalizeFacilitySearch(region)) ||
        (airConditioned && !facility.airConditioned24h)) {
      return null;
    }
    if (minArea == null &&
        maxArea == null &&
        minPrice == null &&
        maxPrice == null) {
      return facility;
    }
    final matches = facility.unitTypeOptions.where((type) {
      final area = (type['areaSqm'] as num?)?.toDouble();
      final price = (type['basePricePerMonth'] as num?)?.toDouble();
      return (minArea == null || (area != null && area >= minArea!)) &&
          (maxArea == null || (area != null && area <= maxArea!)) &&
          (minPrice == null || (price != null && price >= minPrice!)) &&
          (maxPrice == null || (price != null && price <= maxPrice!));
    }).toList();
    return matches.isEmpty ? null : facility.withUnitTypeStats(matches);
  }
}
