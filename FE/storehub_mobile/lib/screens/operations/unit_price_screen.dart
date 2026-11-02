import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/facility_model.dart';
import '../../services/catalog_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

class UnitPriceScreen extends StatefulWidget {
  const UnitPriceScreen({super.key});

  @override
  State<UnitPriceScreen> createState() => _UnitPriceScreenState();
}

class _UnitPriceScreenState extends State<UnitPriceScreen> {
  final CatalogApiService _catalog = CatalogApiService();
  final FacilityAdminApiService _admin = FacilityAdminApiService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  late Future<List<dynamic>> _future;
  List<FacilityModel> _facilities = [];
  FacilityModel? _selectedFacility;
  double _depositPercentage = 20.0;

  @override
  void initState() {
    super.initState();
    _future = _catalog.getUnitTypes();
    _loadFacilitiesAndPolicy();
  }

  Future<void> _loadFacilitiesAndPolicy() async {
    try {
      final list = await _catalog.getFacilities();
      if (!mounted) return;
      setState(() {
        _facilities = list;
        if (_facilities.isNotEmpty) {
          _selectedFacility = _facilities.first;
        }
      });
      if (_selectedFacility != null) {
        await _loadPolicyForFacility(_selectedFacility!.id);
      }
    } catch (_) {}
  }

  Future<void> _loadPolicyForFacility(String facilityId) async {
    try {
      final policy = await _admin.getFacilityPolicyByFacility(facilityId);
      if (!mounted) return;
      setState(() {
        if (policy != null && policy['depositPercentage'] != null) {
          _depositPercentage = (policy['depositPercentage'] as num).toDouble();
        }
      });
    } catch (_) {}
  }

  List<FacilityModel> get _uniqueFacilities {
    final Map<String, FacilityModel> map = {};
    for (final f in _facilities) {
      if (f.id.isNotEmpty && !map.containsKey(f.id)) {
        map[f.id] = f;
      }
    }
    return map.values.toList();
  }

  Future<void> _showBranchPicker() async {
    final list = _uniqueFacilities;
    if (list.isEmpty) return;
    final selected = await showModalBottomSheet<FacilityModel>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Chọn chi nhánh áp dụng % tiền cọc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final f = list[index];
                  final isSelected = f.id == _selectedFacility?.id;
                  return ListTile(
                    leading: Icon(
                      Icons.storefront_outlined,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                    title: Text(
                      f.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      f.city.isNotEmpty
                          ? '${f.city} • ${f.address}'
                          : f.address,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      _onFacilityChanged(selected);
    }
  }

  void _onFacilityChanged(FacilityModel? facility) {
    if (facility == null) return;
    setState(() {
      _selectedFacility = facility;
      _future = _catalog.getUnitTypes(facilityId: facility.id);
    });
    _loadPolicyForFacility(facility.id);
  }

  void _reload() {
    setState(() {
      _future = _catalog.getUnitTypes(facilityId: _selectedFacility?.id);
    });
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _create() async {
    final result = await showDialog<UnitTypeFormData>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => UnitTypeFormDialog(
        title: 'Tạo loại kho mới',
        isCreate: true,
        initialTypeName: '',
        initialDimensions: '',
        initialAreaSqm: 1.0,
        initialPrice: 1000000,
        depositPercentage: _depositPercentage,
        facilityName: _selectedFacility?.name ?? 'Cơ sở hiện tại',
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _admin.createUnitType(
        typeName: result.typeName,
        dimensions: result.dimensions,
        areaSqm: result.areaSqm,
        basePricePerMonth: result.price,
        depositAmount: result.deposit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo loại kho mới thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tạo loại kho thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _edit(Map<String, dynamic> unitType) async {
    final rawPrice = _num(unitType['basePricePerMonth']);
    final rawArea = _num(unitType['areaSqm']);

    final result = await showDialog<UnitTypeFormData>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => UnitTypeFormDialog(
        title: 'Chỉnh sửa kho - ${unitType['typeName'] ?? ''}',
        isCreate: false,
        initialTypeName: unitType['typeName']?.toString() ?? '',
        initialDimensions: unitType['dimensions']?.toString() ?? '',
        initialAreaSqm: rawArea > 0 ? rawArea : 1.0,
        initialPrice: rawPrice > 0 ? rawPrice : 500000,
        depositPercentage: _depositPercentage,
        facilityName: _selectedFacility?.name ?? 'Cơ sở hiện tại',
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _admin.updateUnitType(
        unitTypeId: unitType['id'].toString(),
        typeName: result.typeName,
        dimensions: result.dimensions,
        areaSqm: result.areaSqm,
        basePricePerMonth: result.price,
        depositAmount: result.deposit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật loại kho thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cập nhật thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cấu hình loại kho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Thêm loại kho',
            onPressed: _create,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Thêm loại kho',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Header / Chi nhánh selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Chi nhánh:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _uniqueFacilities.isEmpty ? null : _showBranchPicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedFacility?.name ??
                                  (_uniqueFacilities.isNotEmpty
                                      ? _uniqueFacilities.first.name
                                      : 'Đang tải cơ sở...'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cọc: ${_depositPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Danh sách loại kho',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(
                      message: 'Đang tải loại kho...');
                }

                if (snapshot.hasError) {
                  return AppErrorState(
                    message: snapshot.error
                        .toString()
                        .replaceAll('Exception: ', ''),
                    onRetry: _reload,
                  );
                }

                final items = (snapshot.data ?? [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Chưa có loại kho',
                    message: 'Chưa có loại kho nào trong hệ thống.',
                    action: ElevatedButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm loại kho'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    try {
                      await _future;
                    } catch (_) {}
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final price = _num(item['basePricePerMonth']);
                      // Tiền cọc hiển thị theo % cọc được cấu hình của chi nhánh hiện tại
                      final calculatedDeposit =
                          price * (_depositPercentage / 100);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _edit(item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined,
                                      color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['typeName']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${_num(item['areaSqm'])} m²',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['dimensions']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF334155)),
                                          children: [
                                            const TextSpan(text: 'Thuê '),
                                            TextSpan(
                                              text:
                                                  '${_currency.format(price)}/tháng',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const TextSpan(text: ' • Cọc: '),
                                            TextSpan(
                                              text: _currency.format(
                                                  calculatedDeposit),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit_outlined,
                                    size: 18, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UnitTypeFormData {
  final String typeName;
  final String dimensions;
  final double areaSqm;
  final double price;
  final double deposit;

  const UnitTypeFormData({
    required this.typeName,
    required this.dimensions,
    required this.areaSqm,
    required this.price,
    required this.deposit,
  });
}

class UnitTypeFormDialog extends StatefulWidget {
  final String title;
  final bool isCreate;
  final String initialTypeName;
  final String initialDimensions;
  final double initialAreaSqm;
  final double initialPrice;
  final double depositPercentage;
  final String facilityName;

  const UnitTypeFormDialog({
    super.key,
    required this.title,
    required this.isCreate,
    required this.initialTypeName,
    required this.initialDimensions,
    required this.initialAreaSqm,
    required this.initialPrice,
    required this.depositPercentage,
    required this.facilityName,
  });

  @override
  State<UnitTypeFormDialog> createState() => _UnitTypeFormDialogState();
}

class _UnitTypeFormDialogState extends State<UnitTypeFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _areaController;
  late final TextEditingController _priceController;
  bool _isCustomArea = false;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialTypeName);

    // Phân tích kích thước Dài x Rộng x Cao ban đầu
    double len = 1.0;
    double wid = 1.0;
    double hei = 2.0;
    final dim = widget.initialDimensions.trim();
    final match3 = RegExp(
            r'([\d.]+)\s*m?\s*[xX*×]\s*([\d.]+)\s*m?\s*[xX*×]\s*([\d.]+)\s*m?')
        .firstMatch(dim);
    if (match3 != null) {
      len = double.tryParse(match3.group(1)!) ?? 1.0;
      wid = double.tryParse(match3.group(2)!) ?? 1.0;
      hei = double.tryParse(match3.group(3)!) ?? 2.0;
    } else {
      final match2 = RegExp(r'([\d.]+)\s*m?\s*[xX*×]\s*([\d.]+)\s*m?')
          .firstMatch(dim);
      if (match2 != null) {
        len = double.tryParse(match2.group(1)!) ?? 1.0;
        wid = double.tryParse(match2.group(2)!) ?? 1.0;
        hei = 2.0;
      } else if (widget.initialAreaSqm > 0) {
        len = 1.0;
        wid = widget.initialAreaSqm;
        hei = 2.0;
      }
    }

    _lengthController =
        TextEditingController(text: _formatNumber(len));
    _widthController =
        TextEditingController(text: _formatNumber(wid));
    _heightController =
        TextEditingController(text: _formatNumber(hei));

    final autoArea = (len * wid * 100).round() / 100.0;
    _isCustomArea = false;

    _areaController = TextEditingController(
      text: _formatNumber(autoArea),
    );
    _priceController = TextEditingController(
      text: widget.initialPrice > 0
          ? widget.initialPrice.round().toString()
          : '1000000',
    );
  }

  static String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _lenVal => double.tryParse(_lengthController.text.trim()) ?? 1.0;
  double get _widthVal => double.tryParse(_widthController.text.trim()) ?? 1.0;
  double get _heightVal => double.tryParse(_heightController.text.trim()) ?? 2.0;

  double get _calculatedArea {
    if (_isCustomArea) {
      return double.tryParse(_areaController.text.trim()) ?? (_lenVal * _widthVal);
    }
    return (_lenVal * _widthVal * 100).round() / 100.0;
  }

  double get _calculatedVolume {
    return (_lenVal * _widthVal * _heightVal * 100).round() / 100.0;
  }

  String get _formattedDimensions {
    return '${_formatNumber(_lenVal)}m x ${_formatNumber(_widthVal)}m x ${_formatNumber(_heightVal)}m';
  }

  void _onDimensionChanged() {
    if (!_isCustomArea) {
      _recomputeAreaFromDimensions();
    }
    setState(() {});
  }

  void _recomputeAreaFromDimensions() {
    final area = (_lenVal * _widthVal * 100).round() / 100.0;
    _areaController.text = _formatNumber(area);
  }

  Widget _presetChip(String label, double l, double w, double h) {
    final isSelected = (_lenVal - l).abs() < 0.05 &&
        (_widthVal - w).abs() < 0.05 &&
        (_heightVal - h).abs() < 0.05;
    return InkWell(
      onTap: () {
        setState(() {
          _lengthController.text = _formatNumber(l);
          _widthController.text = _formatNumber(w);
          _heightController.text = _formatNumber(h);
          _isCustomArea = false;
          _recomputeAreaFromDimensions();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  double? _parseAmount(String? value) {
    if (value == null) return null;
    var cleaned = value.trim().replaceAll(',', '').replaceAll(' ', '');
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll('.', '');
    }
    return double.tryParse(cleaned);
  }

  String _formatPreview(String text) {
    final val = _parseAmount(text);
    if (val == null || val < 0) return '';
    return _currency.format(val);
  }

  double get _calculatedDeposit {
    final price = _parseAmount(_priceController.text) ?? 0;
    if (price <= 0) return 0;
    return (price * (widget.depositPercentage / 100)).roundToDouble();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final dimensions = _formattedDimensions;
      final area = _calculatedArea;
      final price = _parseAmount(_priceController.text);
      final deposit = _calculatedDeposit;

      if (name.isNotEmpty &&
          dimensions.isNotEmpty &&
          area > 0 &&
          price != null &&
          price > 0) {
        Navigator.pop(
          context,
          UnitTypeFormData(
            typeName: name,
            dimensions: dimensions,
            areaSqm: area,
            price: price,
            deposit: deposit,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricePreview = _formatPreview(_priceController.text);
    final deposit = _calculatedDeposit;
    final depositPreview = _currency.format(deposit);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isCreate
                            ? Icons.add_business_outlined
                            : Icons.edit_note_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Phân định logic doanh thu & bảo đảm:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Giá thuê: Khoản thu theo tháng (ghi nhận Doanh thu).\n'
                        '• Tiền cọc: Khoản ký quỹ bảo đảm kho (Hoàn lại 100% khi trả kho).\n'
                        '💡 Tiền cọc bảo đảm không sửa trực tiếp mà được tính tự động theo ${widget.depositPercentage.toStringAsFixed(0)}% tiền cọc của chi nhánh (${widget.facilityName}).',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tên loại kho
                const Text(
                  'Tên loại kho',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.drive_file_rename_outline, size: 18),
                    hintText: 'VD: Mini, Small, Medium, Kho cá nhân...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tên loại kho';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Kích thước & Diện tích (Trực quan, tự động tính toán)
                const Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kích thước kho (Dài × Rộng × Cao)',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 3 ô nhập Dài - Rộng - Cao
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chiều Dài',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _lengthController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            onChanged: (_) => _onDimensionChanged(),
                            decoration: InputDecoration(
                              suffixText: 'm',
                              hintText: '2.0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return '> 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chiều Rộng',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _widthController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            onChanged: (_) => _onDimensionChanged(),
                            decoration: InputDecoration(
                              suffixText: 'm',
                              hintText: '3.0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return '> 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chiều Cao',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _heightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              suffixText: 'm',
                              hintText: '2.5',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return '> 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Gợi ý nhanh kích thước phổ biến
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Gợi ý:',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      _presetChip('1×1×1m', 1, 1, 1),
                      const SizedBox(width: 4),
                      _presetChip('1.5×2×2m', 1.5, 2, 2),
                      const SizedBox(width: 4),
                      _presetChip('2×2×2.5m', 2, 2, 2.5),
                      const SizedBox(width: 4),
                      _presetChip('2×3×2.5m', 2, 3, 2.5),
                      const SizedBox(width: 4),
                      _presetChip('3×3×3m', 3, 3, 3),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Card hiển thị kết quả tính Diện tích & Thể tích tự động
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined,
                              size: 15, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'Tự động tính Diện tích & Thể tích',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isCustomArea = !_isCustomArea;
                                if (!_isCustomArea) {
                                  _recomputeAreaFromDimensions();
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                _isCustomArea
                                    ? 'Khóa tự động'
                                    : 'Sửa diện tích lẻ',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Diện tích sàn',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  if (_isCustomArea)
                                    SizedBox(
                                      height: 28,
                                      child: TextFormField(
                                        controller: _areaController,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E40AF)),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                          suffixText: 'm²',
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '${_calculatedArea.toStringAsFixed(_calculatedArea.truncateToDouble() == _calculatedArea ? 1 : 2)} m²',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  Text(
                                    _isCustomArea
                                        ? '(Tùy chỉnh thủ công)'
                                        : 'Dài × Rộng (${_lenVal}m × ${_widthVal}m)',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Thể tích chứa',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_calculatedVolume.toStringAsFixed(_calculatedVolume.truncateToDouble() == _calculatedVolume ? 1 : 2)} m³',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                  Text(
                                    'D × R × C (${_formatNumber(_lenVal)}m × ${_formatNumber(_widthVal)}m × ${_formatNumber(_heightVal)}m)',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '📏 Chuẩn định dạng: $_formattedDimensions',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Giá thuê tháng
                const Text(
                  'Giá thuê tháng',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.sell_outlined, size: 18),
                    suffixText: '₫/tháng',
                    hintText: 'Nhập giá thuê',
                    helperText: pricePreview.isNotEmpty
                        ? '= $pricePreview / tháng'
                        : null,
                    helperStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    final parsed = _parseAmount(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Vui lòng nhập giá lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Tiền cọc bảo đảm (READ-ONLY, tự động tính theo % tiền cọc)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tiền cọc bảo đảm',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 11, color: Color(0xFF64748B)),
                          SizedBox(width: 3),
                          Text(
                            'Tự động tính',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          depositPreview.isNotEmpty ? depositPreview : '0 ₫',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.depositPercentage.toStringAsFixed(0)}% cọc',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '= $depositPreview (Ký quỹ hoàn lại)\n'
                  '💡 Tự động tính theo % cọc của cơ sở: ${_formatPreview(_priceController.text).isNotEmpty ? _formatPreview(_priceController.text) : "0 ₫"} × ${widget.depositPercentage.toStringAsFixed(0)}% = $depositPreview',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Hủy',
                            style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                            widget.isCreate ? Icons.add : Icons.check,
                            size: 16),
                        label: Text(widget.isCreate
                            ? 'Tạo loại kho'
                            : 'Lưu thay đổi'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
