import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/facility_model.dart';
import '../../../models/facility_search_filter.dart';
import '../../../services/catalog_api_service.dart';
import 'facility_detail_screen.dart';

const _blue = Color(0xFF064AE4);
const _ink = Color(0xFF111C36);
const _muted = Color(0xFF65738E);
const _gradient = LinearGradient(
    colors: [Color(0xFF16A2EF), Color(0xFF064AE4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight);
String _number(double value) =>
    NumberFormat.decimalPattern('vi_VN').format(value);
String _area(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
String _range(
    double? min, double? max, String unit, String Function(double) format) {
  if (min != null && max != null) {
    return min == max
        ? '${format(min)} $unit'
        : '${format(min)}–${format(max)} $unit';
  }
  return min != null ? 'Từ ${format(min)} $unit' : 'Đến ${format(max!)} $unit';
}

class ExploreScreen extends StatefulWidget {
  final CatalogApiService? catalogService;
  const ExploreScreen({super.key, this.catalogService});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final _catalog = widget.catalogService ?? CatalogApiService();
  final _search = TextEditingController();
  FacilitySearchFilter _filter = const FacilitySearchFilter();
  List<FacilityModel> _facilities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final facilities = await _catalog.getFacilitiesWithStats();
      if (mounted) {
        setState(() {
          _facilities = facilities;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<FacilitySearchFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _FilterSheet(initial: _filter));
    if (result != null && mounted) setState(() => _filter = result);
  }

  void _open(FacilityModel facility) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FacilityDetailScreen(
              facilityId: facility.id,
              facilityName: facility.name,
              facilityAddress: facility.fullAddress,
              airConditioned24h: facility.airConditioned24h,
              imageUrl: facility.imageUrl,
              images: facility.allImages)));

  @override
  Widget build(BuildContext context) {
    final matches = _facilities
        .map((f) => _filter.apply(f, query: _search.text))
        .whereType<FacilityModel>()
        .toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
            backgroundColor: const Color(0xFFF2F6FF),
            body: Column(children: [
              Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF073A8D), Color(0xFF006AF5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: SafeArea(
                      bottom: false,
                      child: Stack(children: [
                        Positioned(
                            right: -12,
                            top: 0,
                            child: IgnorePointer(
                                child: Icon(Icons.warehouse_outlined,
                                    size: 158,
                                    color:
                                        Colors.white.withValues(alpha: .10)))),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Khám phá cơ sở',
                                      style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Tìm kiếm kho tự phục vụ phù hợp với nhu cầu của bạn',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFE7EFFF),
                                          height: 1.5)),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                          controller: _search,
                                          onChanged: (_) => setState(() {}),
                                          style: const TextStyle(
                                              color: _ink, fontSize: 13),
                                          decoration: InputDecoration(
                                              hintText:
                                                  'Tìm theo tên hoặc địa chỉ cơ sở...',
                                              hintStyle: const TextStyle(
                                                  fontSize: 12, color: _muted),
                                              prefixIcon: const Icon(Icons.search,
                                                  color: _muted, size: 22),
                                              suffixIcon: _search.text.isEmpty
                                                  ? null
                                                  : IconButton(
                                                      tooltip: 'Xóa tìm kiếm',
                                                      onPressed: () => setState(
                                                          _search.clear),
                                                      icon: const Icon(Icons.close,
                                                          size: 18)),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 15),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(28),
                                                  borderSide: BorderSide.none),
                                              enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(28),
                                                  borderSide: BorderSide.none),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Color(0xFFBED6FF))))),
                                    ),
                                    const SizedBox(width: 10),
                                    Stack(clipBehavior: Clip.none, children: [
                                      Container(
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF0046C6),
                                              borderRadius:
                                                  BorderRadius.circular(24)),
                                          child: IconButton(
                                              tooltip: 'Bộ lọc tìm kiếm',
                                              onPressed: _showFilters,
                                              icon: const Icon(Icons.tune,
                                                  color: Colors.white))),
                                      if (_filter.count > 0)
                                        Positioned(
                                            right: -2,
                                            top: -4,
                                            child: IgnorePointer(
                                                child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: Colors.white,
                                                            shape: BoxShape
                                                                .circle),
                                                    child: Text(
                                                        '${_filter.count}',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: _blue,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))))),
                                    ])
                                  ]),
                                ])),
                      ]))),
              if (_filter.count > 0)
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(spacing: 8, runSpacing: 6, children: [
                          if (_filter.hasArea)
                            _chip(
                                _range(_filter.minArea, _filter.maxArea, 'm²',
                                    _area),
                                () => setState(
                                    () => _filter = _filter.withoutArea())),
                          if (_filter.region.isNotEmpty)
                            _chip(
                                _filter.region,
                                () => setState(
                                    () => _filter = _filter.withoutRegion())),
                          if (_filter.hasRent)
                            _chip(
                                _range(_filter.minRent, _filter.maxRent,
                                    'đ/tháng', _number),
                                () => setState(
                                    () => _filter = _filter.withoutRent())),
                        ]))),
              if (_filter.hasArea || _filter.hasRent)
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                        'Giá, diện tích và số ngăn trống hiển thị theo loại kho phù hợp bộ lọc.',
                        style: TextStyle(fontSize: 11, color: _muted))),
              Expanded(child: _body(matches)),
            ])));
  }

  Widget _chip(String label, VoidCallback remove) => InputChip(
      label: Text(label, style: const TextStyle(color: _blue, fontSize: 11)),
      onDeleted: remove,
      deleteIcon: const Icon(Icons.close, size: 16, color: _blue),
      backgroundColor: const Color(0xFFEAF2FF),
      side: const BorderSide(color: Color(0xFFB4CEFF)));

  Widget _body(List<FacilityModel> matches) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, size: 40, color: _muted),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Thử lại'))
              ])));
    }
    return RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              if (matches.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(children: [
                      const Icon(Icons.search_off, size: 48, color: _muted),
                      const SizedBox(height: 12),
                      const Text('Không tìm thấy cơ sở phù hợp.',
                          style: TextStyle(color: _muted)),
                      TextButton(
                          onPressed: () => setState(() {
                                _filter = const FacilitySearchFilter();
                                _search.clear();
                              }),
                          child: const Text('Xóa bộ lọc')),
                    ])),
              for (final facility in matches)
                _FacilityCard(facility: facility, onTap: () => _open(facility)),
            ]));
  }
}

class _FilterSheet extends StatefulWidget {
  final FacilitySearchFilter initial;
  const _FilterSheet({required this.initial});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  final _form = GlobalKey<FormState>();
  late final _areaMin =
      TextEditingController(text: widget.initial.minArea?.toString() ?? '');
  late final _areaMax =
      TextEditingController(text: widget.initial.maxArea?.toString() ?? '');
  late final _rentMin = TextEditingController(
      text: widget.initial.minRent == null
          ? ''
          : _number(widget.initial.minRent!));
  late final _rentMax = TextEditingController(
      text: widget.initial.maxRent == null
          ? ''
          : _number(widget.initial.maxRent!));
  late final _region = TextEditingController(text: widget.initial.region);

  @override
  void dispose() {
    for (final controller in [
      _areaMin,
      _areaMax,
      _rentMin,
      _rentMax,
      _region
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
        context,
        FacilitySearchFilter(
            minArea: parseStorageArea(_areaMin.text),
            maxArea: parseStorageArea(_areaMax.text),
            minRent: parseMonthlyRent(_rentMin.text),
            maxRent: parseMonthlyRent(_rentMax.text),
            region: _region.text.trim()));
  }

  Widget _input(
          String key, String label, TextEditingController controller, bool rent,
          {TextEditingController? lower}) =>
      TextFormField(
          key: ValueKey(key),
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !rent),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          validator: (text) {
            if (text == null || text.trim().isEmpty) return null;
            final parsed =
                rent ? parseMonthlyRent(text) : parseStorageArea(text);
            if (parsed == null) {
              return rent
                  ? 'Nhập số tiền như 500.000'
                  : 'Nhập diện tích hợp lệ';
            }
            final minimum = lower == null
                ? null
                : (rent
                    ? parseMonthlyRent(lower.text)
                    : parseStorageArea(lower.text));
            if (minimum != null && parsed < minimum) {
              return 'Phải lớn hơn hoặc bằng mức từ';
            }
            return null;
          });

  Widget _label(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: _ink)));

  @override
  Widget build(BuildContext context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFD6DDEA),
                                    borderRadius: BorderRadius.circular(3)))),
                        const SizedBox(height: 16),
                        Row(children: [
                          const Expanded(
                              child: Text('Bộ lọc tìm kiếm',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _ink))),
                          TextButton(
                              onPressed: () {
                                _form.currentState!.reset();
                                for (final controller in [
                                  _areaMin,
                                  _areaMax,
                                  _rentMin,
                                  _rentMax,
                                  _region
                                ]) {
                                  controller.clear();
                                }
                              },
                              child: const Text('Xóa tất cả'))
                        ]),
                        const SizedBox(height: 18),
                        _label('Diện tích kho (m²)'),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _input(
                                      'area-min', 'Từ (m²)', _areaMin, false)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _input(
                                      'area-max', 'Đến (m²)', _areaMax, false,
                                      lower: _areaMin))
                            ]),
                        const SizedBox(height: 20),
                        _label('Khu vực'),
                        TextFormField(
                            key: const ValueKey('region'),
                            controller: _region,
                            decoration: InputDecoration(
                                hintText: 'Quận, phường hoặc thành phố',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                    color: _muted),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)))),
                        const SizedBox(height: 8),
                        const Text(
                            'Ví dụ: Quận 1, Thủ Đức, TP HCM. Có thể nhập không dấu.',
                            style: TextStyle(fontSize: 11, color: _muted)),
                        const SizedBox(height: 20),
                        _label('Giá thuê hàng tháng'),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _input('rent-min', 'Từ (đ/tháng)',
                                      _rentMin, true)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _input('rent-max', 'Đến (đ/tháng)',
                                      _rentMax, true,
                                      lower: _rentMin))
                            ]),
                        const SizedBox(height: 8),
                        const Text(
                            'Để trống nếu không giới hạn. Giá tính bằng đồng, ví dụ 500.000.',
                            style: TextStyle(fontSize: 11, color: _muted)),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: _apply,
                            style: FilledButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            child: const Text('Áp dụng')),
                      ])))));
}

class _FacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;
  const _FacilityCard({required this.facility, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = facility.availableUnits;
    final availability = count == null
        ? 'Chưa cập nhật số ngăn'
        : count == 0
            ? 'Đã hết chỗ'
            : 'Còn $count ngăn trống';
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14294E91),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ]),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Stack(children: [
                  Positioned(
                      right: -8,
                      top: -5,
                      child: IgnorePointer(
                          child: Icon(Icons.warehouse_outlined,
                              size: 76, color: _blue.withValues(alpha: .055)))),
                  Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                          width: 88,
                                          height: 94,
                                          child: facility.allImages.isEmpty
                                              ? _fallback()
                                              : Image.network(
                                                  facility.allImages.first,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stack) =>
                                                          _fallback()))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(facility.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color: _ink)),
                                        const SizedBox(height: 7),
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.location_on,
                                                  color: _blue, size: 15),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                  child: Text(
                                                      facility.fullAddress
                                                              .isEmpty
                                                          ? 'Đang cập nhật địa chỉ'
                                                          : facility
                                                              .fullAddress,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 11.5,
                                                          color: _ink,
                                                          height: 1.45))),
                                            ]),
                                      ])),
                                ]),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                    height: 1, color: Color(0xFFF0F3FA))),
                            LayoutBuilder(builder: (context, constraints) {
                              final tags =
                                  Wrap(spacing: 6, runSpacing: 6, children: [
                                if (facility.minAreaSqm != null &&
                                    facility.maxAreaSqm != null)
                                  _tag(
                                      Icons.view_in_ar_outlined,
                                      _range(facility.minAreaSqm,
                                          facility.maxAreaSqm, 'm²', _area),
                                      const Color(0xFF0874DC),
                                      const Color(0xFFE6F4FF)),
                                _tag(
                                    Icons.inventory_2_outlined,
                                    availability,
                                    const Color(0xFFCD6B05),
                                    const Color(0xFFFFF2E2)),
                              ]);
                              final price = Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Giá từ',
                                        style: TextStyle(
                                            fontSize: 11, color: _muted)),
                                    Text(
                                        facility.minPricePerMonth == null
                                            ? 'Liên hệ'
                                            : '${_number(facility.minPricePerMonth!)} đ/tháng',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: _blue)),
                                  ]);
                              if (constraints.maxWidth < 300 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      tags,
                                      const SizedBox(height: 8),
                                      price
                                    ]);
                              }
                              return Row(children: [
                                Expanded(child: tags),
                                const SizedBox(width: 10),
                                SizedBox(width: 126, child: price)
                              ]);
                            }),
                            const SizedBox(height: 14),
                            Container(
                                decoration: BoxDecoration(
                                    gradient: _gradient,
                                    borderRadius: BorderRadius.circular(24)),
                                child: TextButton(
                                    onPressed: onTap,
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 13)),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.visibility_outlined,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Flexible(
                                              child: Text(
                                                  count == 0
                                                      ? 'Xem chi tiết cơ sở'
                                                      : 'Xem chi tiết & đặt kho',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700))),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward,
                                              size: 17)
                                        ]))),
                          ])),
                ]))));
  }

  Widget _fallback() => const ColoredBox(
      color: Color(0xFFE8EFFC),
      child: Icon(Icons.warehouse_outlined, color: _blue, size: 32));
  Widget _tag(IconData icon, String text, Color color, Color background) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: color)))
          ]));
}
