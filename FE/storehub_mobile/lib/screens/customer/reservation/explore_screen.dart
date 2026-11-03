import '../../../widgets/paged_list_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/facility_model.dart';
import '../../../models/facility_search_filter.dart';
import '../../../services/catalog_api_service.dart';
import 'facility_detail_screen.dart';

const _blue = Color(0xFF0755DF);
const _ink = Color(0xFF14213D);
final _money = NumberFormat.decimalPattern('vi_VN');
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
String _range(double? min, double? max, String unit, {bool money = false}) {
  String format(double value) => money ? _money.format(value) : _number(value);
  if (min != null && max != null) {
    return '${format(min)} – ${format(max)} $unit';
  }
  if (min != null) return 'Từ ${format(min)} $unit';
  return 'Đến ${format(max!)} $unit';
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
  List<FacilityModel> _facilities = [];
  bool _loading = true;
  String? _error;
  double? _minArea, _maxArea, _minPrice, _maxPrice;
  String _region = '';
  int get _count => [
        if (_minArea != null || _maxArea != null) 1,
        if (_minPrice != null || _maxPrice != null) 1,
        if (_region.isNotEmpty) 1,
      ].length;
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
      final data = await _catalog.getFacilitiesWithStats();
      if (mounted) {
        setState(() {
          _facilities = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _clear() => setState(() {
        _minArea = _maxArea = _minPrice = _maxPrice = null;
        _region = '';
        _search.clear();
      });

  Future<void> _filters() async {
    final minArea =
        TextEditingController(text: _minArea == null ? '' : _number(_minArea!));
    final maxArea =
        TextEditingController(text: _maxArea == null ? '' : _number(_maxArea!));
    final minPrice = TextEditingController(
        text: _minPrice == null ? '' : _money.format(_minPrice!));
    final maxPrice = TextEditingController(
        text: _maxPrice == null ? '' : _money.format(_maxPrice!));
    final region = TextEditingController(text: _region);
    final form = GlobalKey<FormState>();
    double? parseArea(String value) =>
        double.tryParse(value.trim().replaceAll(',', '.'));
    Widget field(TextEditingController controller, String label, String suffix,
            {TextEditingController? lower, bool price = false}) =>
        TextFormField(
            controller: controller,
            keyboardType: price
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix),
            validator: (value) {
              double? parse(String text) =>
                  price ? parseMonthlyRent(text) : parseArea(text);
              final text = value?.trim() ?? '';
              final amount = parse(text);
              if (text.isNotEmpty &&
                  (amount == null || !amount.isFinite || amount < 0)) {
                return price ? 'Nhập VND, ví dụ 500.000' : 'Nhập số không âm';
              }
              final low = lower == null ? null : parse(lower.text);
              return low != null && amount != null && amount < low
                  ? 'Phải ≥ mức tối thiểu'
                  : null;
            });
    ModalRoute<dynamic>? filterRoute;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        showDragHandle: true,
        useSafeArea: true,
        builder: (ctx) {
          filterRoute = ModalRoute.of(ctx);
          return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Form(
                      key: form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('Bộ lọc tìm kiếm',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _ink))),
                              TextButton(
                                  onPressed: () {
                                    form.currentState?.reset();
                                    for (final c in [
                                      minArea,
                                      maxArea,
                                      minPrice,
                                      maxPrice,
                                      region
                                    ]) {
                                      c.clear();
                                    }
                                  },
                                  child: const Text('Xóa tất cả'))
                            ]),
                            const SizedBox(height: 16),
                            const Text('Diện tích kho',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: field(minArea, 'Diện tích từ', 'm²')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: field(maxArea, 'Diện tích đến', 'm²',
                                      lower: minArea))
                            ]),
                            const SizedBox(height: 20),
                            const Text('Khu vực',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: region,
                                decoration: const InputDecoration(
                                    labelText: 'Tên khu vực',
                                    hintText: 'Thành phố, quận hoặc phường',
                                    prefixIcon:
                                        Icon(Icons.location_on_outlined))),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, children: [
                              for (final city in _facilities
                                  .map((f) => f.city)
                                  .where((c) => c.isNotEmpty)
                                  .toSet())
                                ActionChip(
                                    label: Text(city),
                                    onPressed: () => region.text = city)
                            ]),
                            const SizedBox(height: 20),
                            const Text('Giá thuê hàng tháng',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: field(minPrice, 'Giá từ', 'đ',
                                      price: true)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: field(maxPrice, 'Giá đến', 'đ',
                                      lower: minPrice, price: true))
                            ]),
                            const SizedBox(height: 8),
                            const Text(
                                'Nhập VND, ví dụ: 500000 hoặc 500.000. Chưa gồm tiền cọc và phí dịch vụ.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    height: 1.5)),
                            const SizedBox(height: 12),
                            FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    minimumSize: const Size(0, 48)),
                                onPressed: () {
                                  if (!form.currentState!.validate()) {
                                    return;
                                  }
                                  setState(() {
                                    _minArea = parseArea(minArea.text);
                                    _maxArea = parseArea(maxArea.text);
                                    _minPrice = parseMonthlyRent(minPrice.text);
                                    _maxPrice = parseMonthlyRent(maxPrice.text);
                                    _region = region.text.trim();
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Áp dụng bộ lọc')),
                          ]))));
        });
    await filterRoute?.completed;
    for (final c in [minArea, maxArea, minPrice, maxPrice, region]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = FacilitySearchFilter(
        query: _search.text,
        region: _region,
        minArea: _minArea,
        maxArea: _maxArea,
        minPrice: _minPrice,
        maxPrice: _maxPrice);
    final results =
        _facilities.map(filter.apply).whereType<FacilityModel>().toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
            backgroundColor: const Color(0xFFF2F6FD),
            body: Column(children: [
              Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B3286), Color(0xFF0668F0)])),
                  child: SafeArea(
                      bottom: false,
                      child: Stack(children: [
                        const Positioned(
                            right: -24,
                            top: 0,
                            child: Icon(Icons.warehouse_outlined,
                                size: 160, color: Color(0x1AFFFFFF))),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Khám phá cơ sở',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'Tìm kho tự phục vụ phù hợp với nhu cầu của bạn',
                                      style: TextStyle(
                                          color: Color(0xFFD8E7FF),
                                          fontSize: 13,
                                          height: 1.5)),
                                  const SizedBox(height: 20),
                                  Row(children: [
                                    Expanded(
                                        child: TextField(
                                            controller: _search,
                                            onChanged: (_) => setState(() {}),
                                            decoration: InputDecoration(
                                                hintText:
                                                    'Tìm tên hoặc địa chỉ cơ sở...',
                                                hintStyle: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF6C7D9B)),
                                                prefixIcon: const Icon(
                                                    Icons.search_rounded,
                                                    color: Color(0xFF536585)),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    borderSide:
                                                        BorderSide.none),
                                                enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    borderSide:
                                                        BorderSide.none),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14)))),
                                    const SizedBox(width: 10),
                                    Badge(
                                        isLabelVisible: _count > 0,
                                        label: Text('$_count'),
                                        child: IconButton.filled(
                                            tooltip: 'Bộ lọc tìm kiếm',
                                            onPressed:
                                                _loading ? null : _filters,
                                            style: IconButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF0641B6),
                                                foregroundColor: Colors.white,
                                                minimumSize:
                                                    const Size(48, 48)),
                                            icon: const Icon(
                                                Icons.tune_rounded))),
                                  ]),
                                ])),
                      ]))),
              if (_count > 0)
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(spacing: 8, runSpacing: 6, children: [
                          if (_minArea != null || _maxArea != null)
                            _chip(
                                _range(_minArea, _maxArea, 'm²'),
                                () =>
                                    setState(() => _minArea = _maxArea = null)),
                          if (_region.isNotEmpty)
                            _chip(_region, () => setState(() => _region = '')),
                          if (_minPrice != null || _maxPrice != null)
                            _chip(
                                _range(_minPrice, _maxPrice, 'đ/tháng',
                                    money: true),
                                () => setState(
                                    () => _minPrice = _maxPrice = null)),
                        ]))),
              Expanded(child: _body(results)),
            ])));
  }

  Widget _chip(String label, VoidCallback remove) => InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: _blue)),
      onDeleted: remove,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: _blue,
      backgroundColor: const Color(0xFFEAF2FF),
      side: const BorderSide(color: Color(0xFFB8D2FF)));

  Widget _body(List<FacilityModel> results) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'))
              ])));
    }
    return RefreshIndicator(
        onRefresh: _load,
        child: PagedListView.builder(
            dataKey:
                '${_search.text}|$_region|$_minArea|$_maxArea|$_minPrice|$_maxPrice',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: results.isEmpty ? 1 : results.length,
            itemBuilder: (context, index) {
              if (results.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      const Icon(Icons.search_off_rounded,
                          size: 48, color: Color(0xFF8393AF)),
                      const SizedBox(height: 12),
                      const Text('Không tìm thấy cơ sở phù hợp.'),
                      TextButton(
                          onPressed: _clear, child: const Text('Xóa bộ lọc'))
                    ]));
              }
              final facility = results[index];
              return _FacilityCard(
                  facility: facility,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FacilityDetailScreen(
                              facilityId: facility.id,
                              facilityName: facility.name,
                              facilityAddress: facility.fullAddress,
                              airConditioned24h: facility.airConditioned24h,
                              imageUrl: facility.imageUrl,
                              images: facility.allImages))));
            }));
  }
}

class _FacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;
  const _FacilityCard({required this.facility, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final image = facility.allImages.isEmpty ? null : facility.allImages.first;
    final area = facility.minAreaSqm == null || facility.maxAreaSqm == null
        ? 'Chưa có diện tích'
        : '${_number(facility.minAreaSqm!)} – ${_number(facility.maxAreaSqm!)} m²';
    final available = facility.availableUnits;
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7EEF9)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x111D4280),
                  blurRadius: 14,
                  offset: Offset(0, 6))
            ]),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    width: 94,
                    height: 88,
                    color: const Color(0xFFEAF1FC),
                    child: image == null
                        ? _fallback()
                        : Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => _fallback()))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(facility.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.25)),
                  const SizedBox(height: 7),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on_rounded,
                        color: _blue, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(facility.fullAddress,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF52617A),
                                height: 1.45))),
                  ]),
                ])),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEF2FA)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, box) {
            final chips = Wrap(spacing: 6, runSpacing: 6, children: [
              _pill(Icons.view_in_ar_outlined, area, _blue,
                  const Color(0xFFEAF4FF)),
              _pill(
                  Icons.inventory_2_outlined,
                  available == null
                      ? 'Chưa có số ngăn trống'
                      : available == 0
                          ? 'Đã hết chỗ'
                          : 'Còn $available ngăn trống',
                  const Color(0xFFD97706),
                  const Color(0xFFFFF3E4)),
            ]);
            final price =
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Giá từ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(
                  facility.minPricePerMonth == null
                      ? 'Liên hệ'
                      : '${_money.format(facility.minPricePerMonth)} đ/tháng',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _blue)),
            ]);
            if (box.maxWidth < 300) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [chips, const SizedBox(height: 10), price]);
            }
            return Row(children: [
              Expanded(child: chips),
              const SizedBox(width: 12),
              price
            ]);
          }),
          const SizedBox(height: 12),
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1999EF), Color(0xFF0648D9)]),
                  borderRadius: BorderRadius.circular(28)),
              child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.visibility_outlined,
                                    size: 19, color: Colors.white),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(
                                        available == 0
                                            ? 'Xem chi tiết cơ sở'
                                            : 'Xem chi tiết & đặt kho',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700))),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18, color: Colors.white),
                              ]))))),
        ]));
  }

  Widget _fallback() => const Center(
      child:
          Icon(Icons.warehouse_outlined, size: 38, color: Color(0xFF7B9BC9)));
  Widget _pill(IconData icon, String text, Color color, Color background) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(22)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)))
          ]));
}
