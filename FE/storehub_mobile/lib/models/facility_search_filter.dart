import 'facility_model.dart';

String normalizeFacilitySearch(String text) {
  var result = text.toLowerCase();
  const groups = {
    'a': 'áàảãạâấầẩẫậăắằẳẵặ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  groups.forEach((letter, accents) =>
      result = result.replaceAll(RegExp('[$accents]'), letter));
  result = result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  result = result.replaceAllMapped(
      RegExp(r'\b(?:q\.?|quan|district)\s*(\d+)\b'), (m) => 'district ${m[1]}');
  result = result.replaceAll(RegExp(r'\bphuong\b'), 'ward');
  result = result.replaceAll(
      RegExp(r'\b(?:tp\.?\s*hcm|tphcm|sai gon)\b'), 'ho chi minh');
  result = result.replaceAll(RegExp(r'\b(?:thanh pho|city|tp)\b'), '');
  return result
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

double? parseMonthlyRent(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(value) &&
      !RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(value) &&
      !RegExp(r'^\d{1,3}(?:,\d{3})+$').hasMatch(value) &&
      !RegExp(r'^\d{1,3}(?: \d{3})+$').hasMatch(value)) {
    return null;
  }
  final result = double.tryParse(value.replaceAll(RegExp(r'[., ]'), ''));
  return result != null && result.isFinite && result >= 0 ? result : null;
}

double? parseStorageArea(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) return null;
  final value = double.tryParse(text);
  return value != null && value.isFinite && value >= 0 ? value : null;
}

class FacilitySearchFilter {
  final double? minArea, maxArea, minRent, maxRent;
  final String region;
  const FacilitySearchFilter(
      {this.minArea,
      this.maxArea,
      this.minRent,
      this.maxRent,
      this.region = ''});
  bool get hasArea => minArea != null || maxArea != null;
  bool get hasRent => minRent != null || maxRent != null;
  int get count =>
      (hasArea ? 1 : 0) + (hasRent ? 1 : 0) + (region.trim().isEmpty ? 0 : 1);

  FacilitySearchFilter withoutArea() =>
      FacilitySearchFilter(minRent: minRent, maxRent: maxRent, region: region);
  FacilitySearchFilter withoutRent() =>
      FacilitySearchFilter(minArea: minArea, maxArea: maxArea, region: region);
  FacilitySearchFilter withoutRegion() => FacilitySearchFilter(
      minArea: minArea, maxArea: maxArea, minRent: minRent, maxRent: maxRent);

  FacilityModel? apply(FacilityModel facility, {String query = ''}) {
    if (!facility.isBookable) return null;
    final haystack =
        normalizeFacilitySearch('${facility.name} ${facility.fullAddress}');
    final words = haystack.split(' ');
    bool includes(String input, {bool exactNumbers = false}) =>
        normalizeFacilitySearch(input)
            .split(' ')
            .where((s) => s.isNotEmpty)
            .every((token) => exactNumbers && RegExp(r'^\d+$').hasMatch(token)
                ? words.contains(token)
                : words.any((word) => word.contains(token)));
    if (!includes(query) || !includes(region, exactNumbers: true)) return null;
    if (!hasArea && !hasRent) return facility;
    final matching = facility.unitTypeOptions.where((option) {
      final area = option.areaSqm, price = option.monthlyPrice;
      return (!hasArea ||
              area != null &&
                  (minArea == null || area >= minArea!) &&
                  (maxArea == null || area <= maxArea!)) &&
          (!hasRent ||
              price != null &&
                  (minRent == null || price >= minRent!) &&
                  (maxRent == null || price <= maxRent!));
    }).toList();
    return matching.isEmpty ? null : facility.withUnitOptions(matching);
  }
}
