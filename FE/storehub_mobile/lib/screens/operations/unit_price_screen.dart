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
    });
    _loadPolicyForFacility(facility.id);
  }

  void _reload() {
    setState(() {
      _future = _catalog.getUnitTypes();
    });
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _create() async {
    final result = await showDialog<_UnitTypeFormData>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _UnitTypeFormDialog(
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

    final result = await showDialog<_UnitTypeFormData>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _UnitTypeFormDialog(
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm loại kho'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          // Action banner to add unit type
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách loại kho',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm loại kho'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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

class _UnitTypeFormData {
  final String typeName;
  final String dimensions;
  final double areaSqm;
  final double price;
  final double deposit;

  const _UnitTypeFormData({
    required this.typeName,
    required this.dimensions,
    required this.areaSqm,
    required this.price,
    required this.deposit,
  });
}

class _UnitTypeFormDialog extends StatefulWidget {
  final String title;
  final bool isCreate;
  final String initialTypeName;
  final String initialDimensions;
  final double initialAreaSqm;
  final double initialPrice;
  final double depositPercentage;
  final String facilityName;

  const _UnitTypeFormDialog({
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
  State<_UnitTypeFormDialog> createState() => _UnitTypeFormDialogState();
}

class _UnitTypeFormDialogState extends State<_UnitTypeFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _dimensionsController;
  late final TextEditingController _areaController;
  late final TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialTypeName);
    _dimensionsController =
        TextEditingController(text: widget.initialDimensions);
    _areaController = TextEditingController(
      text: widget.initialAreaSqm > 0
          ? widget.initialAreaSqm.toString()
          : '1.0',
    );
    _priceController = TextEditingController(
      text: widget.initialPrice > 0
          ? widget.initialPrice.round().toString()
          : '1000000',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dimensionsController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    super.dispose();
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
      final dimensions = _dimensionsController.text.trim();
      final area = double.tryParse(_areaController.text.trim());
      final price = _parseAmount(_priceController.text);
      final deposit = _calculatedDeposit;

      if (name.isNotEmpty &&
          dimensions.isNotEmpty &&
          area != null &&
          area > 0 &&
          price != null &&
          price > 0) {
        Navigator.pop(
          context,
          _UnitTypeFormData(
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
                          Text(
                            'Phân định logic doanh thu & bảo đảm:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
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

                // Kích thước & Diện tích
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kích thước (D x R x C)',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dimensionsController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.straighten, size: 18),
                              hintText: 'VD: 1m x 1m x 1m',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập kích thước';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diện tích',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _areaController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              suffixText: 'm²',
                              hintText: 'VD: 1.0',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              final d = double.tryParse(val ?? '');
                              if (d == null || d <= 0) {
                                return 'Lớn hơn 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiền cọc bảo đảm',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155)),
                    ),
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
