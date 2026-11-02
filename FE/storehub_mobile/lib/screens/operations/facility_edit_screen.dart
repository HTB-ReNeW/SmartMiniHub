import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/vi_labels.dart';
import '../../models/facility_management_models.dart';
import '../../services/admin_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../../services/facility_ops_api_service.dart';

/// Create/edit a Facility (FacilityController) and view/edit its
/// FacilityPolicy (FacilityPolicyController) in one place, since a policy
/// always belongs to exactly one facility.
class FacilityEditScreen extends StatefulWidget {
  final Map? facility; // null = create mode

  /// Chỉ Admin được gán Facility Manager (API gán manager yêu cầu role ADMIN).
  final bool canAssignManager;

  /// true: Admin chỉ xem tóm tắt cơ sở và gán Facility Manager (không sửa thông tin/chính sách).
  final bool assignOnly;

  const FacilityEditScreen({
    super.key,
    this.facility,
    this.canAssignManager = false,
    this.assignOnly = false,
  });

  @override
  State<FacilityEditScreen> createState() => _FacilityEditScreenState();
}

class _FacilityEditScreenState extends State<FacilityEditScreen> {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  final FacilityOpsApiService _opsService = FacilityOpsApiService();
  final AdminApiService _adminApiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  String _status = 'ACTIVE';
  bool _airConditioned24h = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 20, minute: 0);

  bool get _isEditing => widget.facility != null;
  bool _isSaving = false;
  List<String> _imageUrls = [];
  bool _isUploadingImage = false;

  // Danh sách các Facility Manager của cơ sở
  List<FacilityStaffModel> _managers = [];
  bool _isLoadingManagers = false;
  String? _managerId;
  String? _managerName;
  String? _managerEmail;

  // Policy state
  bool _isLoadingPolicy = false;
  Map<String, dynamic>? _policy;
  final _depositController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _minMonthsController = TextEditingController();
  final _renewalWindowController = TextEditingController();
  final _fullRefundHoursController = TextEditingController(text: '24');
  final _partialRefundHoursController = TextEditingController(text: '24');
  final _partialRefundPercentController = TextEditingController(text: '50.0');
  final _returnNoticeController = TextEditingController();
  final _refundSlaController = TextEditingController();
  final _graceController = TextEditingController();
  final _accessDisableController = TextEditingController();
  final _sealingController = TextEditingController();
  final _managementFeeController = TextEditingController();
  final _discountMonthsController = TextEditingController(text: '0');
  final _discountPercentController = TextEditingController(text: '0.0');
  final _maxAdvanceReservationDaysController = TextEditingController();
  final _prohibitedItemsController = TextEditingController();
  final _termsAndConditionsController = TextEditingController();
  final _termsVersionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    _nameController = TextEditingController(text: f?['name']?.toString() ?? '');
    _codeController = TextEditingController(text: f?['code']?.toString() ?? '');
    _addressController =
        TextEditingController(text: f?['address']?.toString() ?? '');
    _cityController = TextEditingController(text: f?['city']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: f?['contactPhone']?.toString() ?? '');
    _emailController =
        TextEditingController(text: f?['email']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: f?['description']?.toString() ?? '');
    _imageUrlController =
        TextEditingController(text: f?['imageUrl']?.toString() ?? '');

    if (f != null && f['images'] is List) {
      _imageUrls = (f['images'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (f != null &&
        f['images'] is String &&
        (f['images'] as String).isNotEmpty) {
      _imageUrls = (f['images'] as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (_imageUrls.isEmpty && _imageUrlController.text.trim().isNotEmpty) {
      _imageUrls.add(_imageUrlController.text.trim());
    }

    _status = f?['status']?.toString() ?? 'ACTIVE';
    _airConditioned24h = f?['airConditioned24h'] == true;
    _openTime = _parseTime(f?['openTime']) ?? _openTime;
    _closeTime = _parseTime(f?['closeTime']) ?? _closeTime;
    _managerId = f?['managerId']?.toString();
    _managerName = f?['managerName']?.toString();

    if (_isEditing) {
      if (!widget.assignOnly) _loadPolicy();
      _loadManagers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _depositController.dispose();
    _lateFeeController.dispose();
    _minMonthsController.dispose();
    _renewalWindowController.dispose();
    _fullRefundHoursController.dispose();
    _partialRefundHoursController.dispose();
    _partialRefundPercentController.dispose();
    _returnNoticeController.dispose();
    _refundSlaController.dispose();
    _graceController.dispose();
    _accessDisableController.dispose();
    _sealingController.dispose();
    _managementFeeController.dispose();
    _discountMonthsController.dispose();
    _discountPercentController.dispose();
    _maxAdvanceReservationDaysController.dispose();
    _prohibitedItemsController.dispose();
    _termsAndConditionsController.dispose();
    _termsVersionController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicy({String? policyId}) async {
    setState(() => _isLoadingPolicy = true);
    try {
      final facilityId = widget.facility!['id'].toString();
      // Sau khi lưu đã biết id chính sách thì tải đúng bản ghi đó; lần đầu tải theo cơ sở.
      final policy = policyId != null
          ? await _service.getFacilityPolicyById(policyId)
          : await _service.getFacilityPolicyByFacility(facilityId);
      if (!mounted) return;
      setState(() {
        _policy = policy;
        if (policy != null) {
          _depositController.text =
              (policy['depositPercentage'] ?? '').toString();
          _lateFeeController.text = (policy['dailyLateFee'] ?? '').toString();
          _minMonthsController.text =
              (policy['minimumRentalMonths'] ?? '').toString();
          _renewalWindowController.text =
              (policy['renewalWindowDays'] ?? '').toString();
          _fullRefundHoursController.text =
              (policy['cancellationFullRefundHours'] ?? '24').toString();
          _partialRefundHoursController.text =
              (policy['cancellationPartialRefundHours'] ?? '24').toString();
          _partialRefundPercentController.text =
              (policy['cancellationPartialRefundPercent'] ?? '').toString();
          _returnNoticeController.text =
              (policy['returnNoticeDays'] ?? '').toString();
          _refundSlaController.text =
              (policy['depositRefundSlaDays'] ?? '').toString();
          _graceController.text = (policy['overdueGraceDays'] ?? '').toString();
          _accessDisableController.text =
              (policy['overdueAccessDisableDays'] ?? '').toString();
          _sealingController.text =
              (policy['overdueSealingDays'] ?? '').toString();
          _managementFeeController.text =
              (policy['managementFeePerMonth'] ?? '').toString();
          _discountMonthsController.text =
              (policy['longTermDiscountMinMonths'] ?? '').toString();
          _discountPercentController.text =
              (policy['longTermDiscountPercent'] ?? '').toString();
          _maxAdvanceReservationDaysController.text =
              (policy['maxAdvanceReservationDays'] ?? '14').toString();
          _prohibitedItemsController.text =
              (policy['prohibitedItems'] ?? '').toString();
          _termsAndConditionsController.text =
              (policy['termsAndConditions'] ?? '').toString();
          _termsVersionController.text =
              (policy['termsVersion'] ?? 'v2026.1').toString();
        }
        _isLoadingPolicy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPolicy = false);
    }
  }

  Future<void> _pickAndUploadMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isEmpty) return;

      setState(() {
        _isUploadingImage = true;
      });

      final paths = pickedList.map((x) => x.path).toList();
      final uploadedUrls = await _service.uploadFacilityImages(paths);

      if (!mounted) return;
      setState(() {
        for (final url in uploadedUrls) {
          if (url.isNotEmpty && !_imageUrls.contains(url)) {
            _imageUrls.add(url);
          }
        }
        if (_imageUrls.isNotEmpty) {
          _imageUrlController.text = _imageUrls.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tải ảnh thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final uploadedUrl = await _service.uploadFacilityImage(
        picked.path,
        facilityId: widget.facility?['id']?.toString(),
      );

      if (!mounted) return;
      setState(() {
        if (uploadedUrl.isNotEmpty && !_imageUrls.contains(uploadedUrl)) {
          _imageUrls.add(uploadedUrl);
        }
        if (_imageUrls.isNotEmpty) {
          _imageUrlController.text = _imageUrls.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tải ảnh thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      if (_imageUrls.isNotEmpty) {
        _imageUrlController.text = _imageUrls.first;
      } else {
        _imageUrlController.clear();
      }
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thêm ảnh cơ sở kho',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primaryContainer),
                title: const Text('Chọn nhiều ảnh từ thư viện'),
                subtitle:
                    const Text('Có thể chọn cùng lúc nhiều ảnh từ thiết bị'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadMultipleImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primaryContainer),
                title: const Text('Chụp ảnh mới bằng camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFromCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFacility() async {
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đợi ảnh tải lên hoàn tất...'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final opens = _openTime.hour * 60 + _openTime.minute;
    final closes = _closeTime.hour * 60 + _closeTime.minute;
    if (opens >= closes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Giờ đóng cửa phải sau giờ mở cửa trong cùng một ngày.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _isSaving = true);
    final body = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'address': _addressController.text.trim(),
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'contactPhone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      'imageUrl': _imageUrls.isNotEmpty
          ? _imageUrls.first
          : _imageUrlController.text.trim(),
      'images': _imageUrls,
      if (_isEditing) 'status': _status,
      'airConditioned24h': _airConditioned24h,
      'openTime': _formatTime(_openTime),
      'closeTime': _formatTime(_closeTime),
    };

    try {
      if (_isEditing) {
        await _service.updateFacility(widget.facility!['id'].toString(), body);
      } else {
        await _service.createFacility(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Đã cập nhật cơ sở' : 'Đã tạo cơ sở'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TimeOfDay? _parseTime(dynamic value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickFacilityTime({required bool opening}) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: opening ? _openTime : _closeTime,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (opening) {
        _openTime = chosen;
      } else {
        _closeTime = chosen;
      }
    });
  }

  InputDecoration _dec(String label, {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    );
  }

  Widget _policyField(
    TextEditingController controller,
    String label, {
    bool int_ = false,
    String? suffix,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: int_
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: _dec(label, hint: hint, suffix: suffix),
    );
  }

  Future<void> _savePolicy() async {
    final deposit = double.tryParse(_depositController.text);
    final lateFee = double.tryParse(_lateFeeController.text);
    final minMonths = int.tryParse(_minMonthsController.text);
    final renewalWindow = int.tryParse(_renewalWindowController.text);
    final fullRefundHours = int.tryParse(_fullRefundHoursController.text);
    final partialRefundHours = int.tryParse(_partialRefundHoursController.text);
    final partialRefundPercent =
        double.tryParse(_partialRefundPercentController.text);
    final returnNotice = int.tryParse(_returnNoticeController.text);
    final refundSla = int.tryParse(_refundSlaController.text);
    final grace = int.tryParse(_graceController.text);
    final accessDisable = int.tryParse(_accessDisableController.text);
    final sealing = int.tryParse(_sealingController.text);
    final managementFee = double.tryParse(_managementFeeController.text);
    final discountMonths = int.tryParse(_discountMonthsController.text) ?? 0;
    final discountPercent = double.tryParse(_discountPercentController.text) ?? 0.0;
    final maxAdvanceDays = int.tryParse(_maxAdvanceReservationDaysController.text) ?? 14;

    if (deposit == null ||
        managementFee == null ||
        lateFee == null ||
        minMonths == null ||
        renewalWindow == null ||
        fullRefundHours == null ||
        partialRefundHours == null ||
        partialRefundPercent == null ||
        returnNotice == null ||
        refundSla == null ||
        grace == null ||
        accessDisable == null ||
        sealing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vui lòng nhập số hợp lệ cho các trường chính sách.')),
      );
      return;
    }

    if (grace < 0 || grace > accessDisable || accessDisable > sealing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Các mốc tính từ ngày hết hạn phải thỏa: 0 ≤ ân hạn ≤ khóa truy cập ≤ chờ niêm phong.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (fullRefundHours < partialRefundHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Số giờ hoàn 100% phải lớn hơn hoặc bằng số giờ hoàn một phần.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final facilityId = widget.facility!['id'].toString();
    final body = {
      'facilityId': facilityId,
      'depositPercentage': deposit,
      'renewalWindowDays': renewalWindow,
      'cancellationFullRefundHours': fullRefundHours,
      'cancellationPartialRefundHours': partialRefundHours,
      'cancellationPartialRefundPercent': partialRefundPercent,
      'returnNoticeDays': returnNotice,
      'depositRefundSlaDays': refundSla,
      'dailyLateFee': lateFee,
      'overdueGraceDays': grace,
      'overdueAccessDisableDays': accessDisable,
      'overdueSealingDays': sealing,
      'minimumRentalMonths': minMonths,
      'maxAdvanceReservationDays': maxAdvanceDays,
      'managementFeePerMonth': managementFee,
      'longTermDiscountMinMonths': discountMonths,
      'longTermDiscountPercent': discountPercent,
      'prohibitedItems': _prohibitedItemsController.text.trim(),
      'termsAndConditions': _termsAndConditionsController.text.trim(),
      'termsVersion': _termsVersionController.text.trim(),
    };

    try {
      String? savedPolicyId;
      if (_policy != null) {
        final updated =
            await _service.updateFacilityPolicy(_policy!['id'].toString(), body);
        savedPolicyId = (updated['id'] ?? _policy!['id'])?.toString();
      } else {
        final created = await _service.createFacilityPolicy(body);
        savedPolicyId = created['id']?.toString();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã lưu chính sách'), backgroundColor: AppColors.success),
      );
      _loadPolicy(policyId: savedPolicyId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadManagers() async {
    final facilityId = widget.facility?['id']?.toString();
    if (facilityId == null || facilityId.isEmpty) return;

    setState(() => _isLoadingManagers = true);
    try {
      final list = await _opsService.getFacilityManagers(facilityId);
      if (mounted) {
        setState(() {
          _managers = list;
          _isLoadingManagers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        if (_managers.isEmpty && _managerId != null && _managerName != null) {
          _managers = [
            FacilityStaffModel(
              id: _managerId!,
              fullName: _managerName!,
              email: _managerEmail ?? '',
              role: 'FACILITY_MANAGER',
            )
          ];
        }
        setState(() => _isLoadingManagers = false);
      }
    }
  }

  Future<void> _confirmRemoveManager(FacilityStaffModel mgr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận gỡ quản lý'),
        content: Text(
            'Bạn có chắc muốn gỡ tài khoản "${mgr.fullName}" khỏi ban quản lý cơ sở này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ bỏ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final facilityId = widget.facility!['id'].toString();
      await _opsService.unassignManagerFromFacility(facilityId, mgr.id);
      await _loadManagers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gỡ "${mgr.fullName}" khỏi ban quản lý cơ sở'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Không thể gỡ quản lý: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openAssignManagerSheet() async {
    final facilityId = widget.facility?['id']?.toString() ?? '';
    final facilityName = _nameController.text.trim();
    final currentManagerIds = _managers.map((m) => m.id).toSet();
    if (_managerId != null && _managerId!.isNotEmpty) {
      currentManagerIds.add(_managerId!);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FacilityManagerAssignmentSheet(
        facilityId: facilityId,
        facilityName: facilityName,
        currentManagerIds: currentManagerIds,
        adminApiService: _adminApiService,
        facilityService: _service,
        opsService: _opsService,
        onManagerAssigned: () async {
          await _loadManagers();
        },
      ),
    );
  }

  static const SizedBox _gap = SizedBox(height: 14);

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _pair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildManagerCard() {
    return _section(
      icon: Icons.manage_accounts_outlined,
      title: 'Quản lý cơ sở (${_managers.length})',
      subtitle:
          'Các tài khoản phụ trách vận hành cơ sở này. Admin có thể thêm nhiều quản lý.',
      children: [
        if (_isLoadingManagers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_managers.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_off_outlined,
                    color: AppColors.onSurfaceVariant, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chưa có quản lý cơ sở nào được gán.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          ..._managers.map((mgr) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceContainerHigh),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    radius: 18,
                    child: Text(
                      mgr.fullName.isNotEmpty
                          ? mgr.fullName[0].toUpperCase()
                          : 'M',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                mgr.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Quản lý',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary),
                              ),
                            ),
                          ],
                        ),
                        if (mgr.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            mgr.email,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.canAssignManager)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.error, size: 20),
                      tooltip: 'Gỡ khỏi cơ sở',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmRemoveManager(mgr),
                    ),
                ],
              ),
            );
          }),
        if (widget.canAssignManager) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _openAssignManagerSheet,
            icon: const Icon(Icons.person_add_alt, size: 16),
            label: Text(_managers.isEmpty
                ? 'Gán quản lý cơ sở'
                : 'Thêm quản lý cơ sở'),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              icon: Icons.business_outlined,
              title: 'Thông tin cơ sở',
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _dec('Tên cơ sở'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nhập tên (ít nhất 2 ký tự)'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _codeController,
                  decoration: _dec('Mã cơ sở', hint: 'VD: HCM-01'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nhập mã (ít nhất 2 ký tự)'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _addressController,
                  decoration: _dec('Địa chỉ'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập địa chỉ'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _cityController,
                  decoration: _dec('Thành phố (không bắt buộc)'),
                ),
                if (_isEditing) ...[
                  _gap,
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _dec('Trạng thái'),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
                      DropdownMenuItem(
                          value: 'INACTIVE', child: Text('Tạm ngưng')),
                      DropdownMenuItem(
                          value: 'MAINTENANCE', child: Text('Bảo trì')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ],

                const SizedBox(height: 6),
                const Text(
                  'Giờ làm việc của cơ sở',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Khách chỉ đặt được lịch hẹn nhận/trả kho trong khung giờ này.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFacilityTime(opening: true),
                        icon: const Icon(Icons.schedule),
                        label: Text('Mở cửa ${_openTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFacilityTime(opening: false),
                        icon: const Icon(Icons.schedule),
                        label: Text('Đóng cửa ${_closeTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                _gap,
                const Text(
                  'Hình ảnh cơ sở kho',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_imageUrls.isEmpty)
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _showImageSourceSheet,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 44,
                                    color: AppColors.primaryContainer
                                        .withValues(alpha: 0.8)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Bấm để chọn nhiều ảnh từ máy hoặc chụp ảnh',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (_isUploadingImage)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white),
                                    SizedBox(height: 10),
                                    Text(
                                      'Đang tải ảnh lên...',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Đã tải lên ${_imageUrls.length} ảnh',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryContainer),
                          ),
                          TextButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : _showImageSourceSheet,
                            icon:
                                const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('Thêm ảnh',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageUrls.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            if (idx == _imageUrls.length) {
                              return GestureDetector(
                                onTap: _isUploadingImage
                                    ? null
                                    : _showImageSourceSheet,
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 28,
                                          color: AppColors.primaryContainer),
                                      SizedBox(height: 6),
                                      Text(
                                        '+ Thêm',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primaryContainer,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final url = _imageUrls[idx];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.black12,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                        child: Icon(Icons.broken_image_outlined,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                if (idx == 0)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Ảnh chính',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImageAt(idx),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700
                                            .withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (_isUploadingImage) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Đang tải ảnh lên...',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryContainer)),
                          ],
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            _section(
              icon: Icons.contact_phone_outlined,
              title: 'Liên hệ',
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Số điện thoại (không bắt buộc)'),
                ),
                _gap,
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email (không bắt buộc)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim())) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                _gap,
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _dec('Mô tả (không bắt buộc)'),
                ),
              ],
            ),
            if (_isEditing) _buildManagerCard(),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveFacility,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo cơ sở'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTab() {
    if (_isLoadingPolicy) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text(
              _policy == null
                  ? 'Cơ sở này chưa có chính sách thuê.'
                  : 'Đang chỉnh sửa chính sách thuê của cơ sở này.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ),
          _section(
            icon: Icons.payments_outlined,
            title: 'Tiền cọc & phí',
            children: [
              _pair(
                _policyField(_depositController, 'Tiền cọc', suffix: '%'),
                _policyField(_lateFeeController, 'Phí trễ hạn mỗi ngày',
                    suffix: 'VND'),
              ),
              _gap,
              _pair(
                _policyField(_minMonthsController, 'Thuê tối thiểu',
                    int_: true, suffix: 'tháng'),
                _policyField(_refundSlaController, 'Hoàn cọc trong',
                    int_: true, suffix: 'ngày'),
              ),
            ],
          ),
          _section(
            icon: Icons.autorenew,
            title: 'Đặt chỗ, gia hạn & trả kho',
            children: [
              _pair(
                _policyField(_maxAdvanceReservationDaysController,
                    'Đặt trước tối đa',
                    int_: true, suffix: 'ngày', hint: 'VD: 14'),
                _policyField(_renewalWindowController, 'Cho gia hạn trước hạn',
                    int_: true, suffix: 'ngày'),
              ),
              _gap,
              _policyField(_returnNoticeController, 'Báo trước khi trả kho',
                  int_: true, suffix: 'ngày'),
            ],
          ),
          _section(
            icon: Icons.sell_outlined,
            title: 'Phí quản lý',
            subtitle: 'Phí quản lý = 0 nghĩa là miễn phí.',
            children: [
              _policyField(_managementFeeController, 'Phí quản lý',
                  suffix: 'VND / tháng'),
            ],
          ),
          _section(
            icon: Icons.event_busy_outlined,
            title: 'Hoàn tiền khi hủy',
            subtitle: 'Tính theo số giờ trước ngày bắt đầu thuê.',
            children: [
              _pair(
                _policyField(_fullRefundHoursController, 'Hoàn 100% nếu hủy trước',
                    int_: true, suffix: 'giờ'),
                _policyField(_partialRefundHoursController, 'Hoàn một phần nếu hủy sau',
                    int_: true, suffix: 'giờ'),
              ),
              _gap,
              _policyField(
                  _partialRefundPercentController, 'Tỷ lệ hoàn một phần',
                  suffix: '%'),
            ],
          ),
          _section(
            icon: Icons.warning_amber_rounded,
            title: 'Xử lý quá hạn',
            subtitle: 'Cả ba mốc tính từ ngày hết hạn: ân hạn ≤ khóa truy cập ≤ chờ niêm phong. Ân hạn chỉ miễn phí trễ hạn.',
            children: [
              _policyField(_graceController, 'Ân hạn phí trễ hạn',
                  int_: true, suffix: 'ngày'),
              _gap,
              _pair(
                _policyField(_accessDisableController, 'Khóa mã ra vào sau',
                    int_: true, suffix: 'ngày'),
                _policyField(_sealingController, 'Chờ duyệt niêm phong sau',
                    int_: true, suffix: 'ngày'),
              ),
            ],
          ),
          _section(
            icon: Icons.gavel_outlined,
            title: 'Điều khoản & hàng cấm',
            subtitle: 'Được cấu hình theo chính sách của cơ sở.',
            children: [
              _policyField(_termsVersionController, 'Phiên bản điều khoản',
                  hint: 'VD: v2026.1'),
              _gap,
              TextFormField(
                controller: _prohibitedItemsController,
                maxLines: 4,
                decoration: _dec(
                  'Hàng cấm lưu kho',
                  hint: 'Ngăn cách các mục bằng dấu chấm phẩy (;)',
                ),
              ),
              _gap,
              TextFormField(
                controller: _termsAndConditionsController,
                maxLines: 5,
                decoration: _dec(
                  'Tóm tắt điều khoản',
                  hint: 'Nội quy, an toàn, trách nhiệm...',
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _savePolicy,
            child: Text(_policy == null ? 'Tạo chính sách' : 'Lưu chính sách'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assignOnly) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Gán quản lý cơ sở')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              icon: Icons.warehouse_outlined,
              title: _nameController.text,
              subtitle:
                  '${_codeController.text} • ${_addressController.text}',
              children: const [],
            ),
            _buildManagerCard(),
          ],
        ),
      );
    }

    if (!_isEditing) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Thêm cơ sở')),
        body: _buildDetailsTab(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Sửa cơ sở'),
          bottom: const TabBar(
            labelColor: AppColors.secondaryContainer,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.secondaryContainer,
            tabs: [Tab(text: 'Thông tin'), Tab(text: 'Chính sách thuê')],
          ),
        ),
        body: TabBarView(
          children: [_buildDetailsTab(), _buildPolicyTab()],
        ),
      ),
    );
  }
}

enum _ManagerFilter { unassigned, allFacilityManagers, allUsers }

class FacilityManagerAssignmentSheet extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final Set<String> currentManagerIds;
  final AdminApiService adminApiService;
  final FacilityAdminApiService facilityService;
  final FacilityOpsApiService opsService;
  final Future<void> Function() onManagerAssigned;

  const FacilityManagerAssignmentSheet({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.currentManagerIds,
    required this.adminApiService,
    required this.facilityService,
    required this.opsService,
    required this.onManagerAssigned,
  });

  @override
  State<FacilityManagerAssignmentSheet> createState() =>
      _FacilityManagerAssignmentSheetState();
}

class _FacilityManagerAssignmentSheetState
    extends State<FacilityManagerAssignmentSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, String> _managedFacilityMap = {};
  late Set<String> _currentAssignedIds;
  _ManagerFilter _activeFilter = _ManagerFilter.allFacilityManagers;
  final TextEditingController _searchController = TextEditingController();
  String? _assigningUserId;

  @override
  void initState() {
    super.initState();
    _currentAssignedIds = Set<String>.from(widget.currentManagerIds);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.adminApiService.getUsers(),
        widget.facilityService
            .getFacilities()
            .catchError((_) => <dynamic>[]),
        if (widget.facilityId.isNotEmpty)
          widget.opsService
              .getFacilityManagers(widget.facilityId)
              .catchError((_) => <FacilityStaffModel>[])
        else
          Future.value(<FacilityStaffModel>[]),
      ]);

      final usersRaw = results[0];
      final facilitiesRaw = results[1];
      final currentMgrs = results[2] as List<FacilityStaffModel>;

      for (final cm in currentMgrs) {
        _currentAssignedIds.add(cm.id);
      }

      final managedMap = <String, String>{};
      for (final item in facilitiesRaw.whereType<Map>()) {
        final fId = item['id']?.toString() ?? '';
        final mId = item['managerId']?.toString();
        final fName = item['name']?.toString() ?? '';
        if (mId != null && mId.isNotEmpty && fName.isNotEmpty) {
          managedMap[mId] = fName;
        }
        if (fId == widget.facilityId && mId != null && mId.isNotEmpty) {
          _currentAssignedIds.add(mId);
        }
      }

      final parsed = usersRaw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((u) {
        final rawRole = _getRawRole(u);
        return rawRole != 'ADMIN';
      }).toList();

      if (mounted) {
        setState(() {
          _allUsers = parsed;
          _managedFacilityMap = managedMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _getRawRole(Map<String, dynamic> u) {
    return (u['roleName']?.toString() ??
            (u['role'] is Map
                ? u['role']['name']?.toString()
                : u['role']?.toString()) ??
            '')
        .toUpperCase()
        .replaceAll('ROLE_', '');
  }

  bool _isFacilityManager(Map<String, dynamic> u) {
    return _getRawRole(u) == 'FACILITY_MANAGER';
  }

  ({bool isAssignedToThis, bool isUnassigned, String facilityName})
      _getAssignmentInfo(Map<String, dynamic> u) {
    final userId = u['id']?.toString() ?? '';
    final rawFacilityId = u['facilityId']?.toString() ?? '';
    final directFacilityName = u['facilityName']?.toString() ?? '';
    final mappedFacilityName = _managedFacilityMap[userId] ?? '';
    final effectiveFacilityName = directFacilityName.isNotEmpty
        ? directFacilityName
        : mappedFacilityName;

    final isAssignedToThis = _currentAssignedIds.contains(userId) ||
        (rawFacilityId.isNotEmpty && rawFacilityId == widget.facilityId);

    final isUnassigned = !isAssignedToThis &&
        rawFacilityId.isEmpty &&
        effectiveFacilityName.isEmpty;

    return (
      isAssignedToThis: isAssignedToThis,
      isUnassigned: isUnassigned,
      facilityName:
          isAssignedToThis ? widget.facilityName : effectiveFacilityName,
    );
  }

  int get _unassignedCount => _allUsers
      .where((u) => _isFacilityManager(u) && _getAssignmentInfo(u).isUnassigned)
      .length;

  int get _facilityManagersCount =>
      _allUsers.where((u) => _isFacilityManager(u)).length;

  int get _allUsersCount => _allUsers.length;

  List<Map<String, dynamic>> _getFilteredUsers() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allUsers.where((u) {
      final info = _getAssignmentInfo(u);
      final isMgr = _isFacilityManager(u);

      // Lọc theo Tab bộ lọc
      switch (_activeFilter) {
        case _ManagerFilter.unassigned:
          if (!isMgr || !info.isUnassigned) return false;
          break;
        case _ManagerFilter.allFacilityManagers:
          if (!isMgr) return false;
          break;
        case _ManagerFilter.allUsers:
          break;
      }

      // Lọc theo Search query
      if (query.isNotEmpty) {
        final rawRole = _getRawRole(u);
        final haystack = [
          u['fullName'],
          u['email'],
          u['username'],
          u['phone'],
          ViLabels.role(rawRole),
          rawRole,
          info.facilityName,
        ].whereType<String>().join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sắp xếp: Quản lý cơ sở này lên #1, kế tiếp Quản lý đang rảnh, rồi đến Quản lý cơ sở khác
    filtered.sort((a, b) {
      final infoA = _getAssignmentInfo(a);
      final infoB = _getAssignmentInfo(b);
      final isMgrA = _isFacilityManager(a);
      final isMgrB = _isFacilityManager(b);

      int score(Map<String, dynamic> u, bool isMgr, bool isUnassigned,
          bool isThis) {
        if (isThis) return 0; // Đang quản lý cơ sở này -> Ưu tiên hiện đầu tiên
        if (isMgr && isUnassigned) return 1; // Quản lý chưa có cơ sở -> Kế tiếp
        if (isMgr) return 2; // Quản lý cơ sở khác -> Kế tiếp
        if (_getRawRole(u) == 'STAFF') return 3;
        return 4;
      }

      final scoreA =
          score(a, isMgrA, infoA.isUnassigned, infoA.isAssignedToThis);
      final scoreB =
          score(b, isMgrB, infoB.isUnassigned, infoB.isAssignedToThis);

      final cmp = scoreA.compareTo(scoreB);
      if (cmp != 0) return cmp;

      final nA = (a['fullName']?.toString() ??
              a['username']?.toString() ??
              '')
          .toLowerCase();
      final nB = (b['fullName']?.toString() ??
              b['username']?.toString() ??
              '')
          .toLowerCase();
      return nA.compareTo(nB);
    });

    return filtered;
  }

  Future<void> _handleAssign(Map<String, dynamic> u) async {
    final userId = u['id']?.toString() ?? '';
    final name = u['fullName']?.toString() ?? u['username']?.toString() ?? '';
    final info = _getAssignmentInfo(u);

    if (info.isAssignedToThis) return;

    if (!info.isUnassigned && info.facilityName.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xác nhận phân công',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
              'Tài khoản "$name" hiện đang phụ trách cơ sở "${info.facilityName}".\n\n'
              'Bạn có chắc chắn muốn phân công thêm tài khoản này cùng quản lý cơ sở "${widget.facilityName}" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý phân công'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _assigningUserId = userId);
    try {
      await widget.opsService
          .assignManagerToFacility(widget.facilityId, userId);
      await widget.onManagerAssigned();
      if (!mounted) return;
      setState(() {
        _currentAssignedIds.add(userId);
        _assigningUserId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Đã thêm "$name" vào ban quản lý "${widget.facilityName}"'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigningUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Không thể gán quản lý: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleUnassign(Map<String, dynamic> u) async {
    final userId = u['id']?.toString() ?? '';
    final name = u['fullName']?.toString() ?? u['username']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gỡ quyền quản lý cơ sở',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
            'Bạn có chắc chắn muốn gỡ quyền quản lý cơ sở "${widget.facilityName}" của tài khoản "$name" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ quyền'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _assigningUserId = userId);
    try {
      await widget.opsService
          .unassignManagerFromFacility(widget.facilityId, userId);
      await widget.onManagerAssigned();
      if (!mounted) return;
      setState(() {
        _currentAssignedIds.remove(userId);
        _assigningUserId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Đã gỡ "$name" khỏi ban quản lý "${widget.facilityName}"'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigningUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Không thể gỡ quản lý: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredUsers = _getFilteredUsers();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.manage_accounts_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gán Quản lý cơ sở (Facility Manager)',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Cơ sở: ${widget.facilityName.isNotEmpty ? widget.facilityName : "Chi nhánh"}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, email, cơ sở đang quản lý...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip(
                    filter: _ManagerFilter.allFacilityManagers,
                    label: '🏢 Quản lý cơ sở ($_facilityManagersCount)',
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    filter: _ManagerFilter.unassigned,
                    label: '🟢 Chưa có cơ sở ($_unassignedCount)',
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    filter: _ManagerFilter.allUsers,
                    label: '👥 Tất cả tài khoản ($_allUsersCount)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Unified Body List
            Expanded(
              child: _buildBody(filteredUsers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required _ManagerFilter filter,
    required String label,
  }) {
    final isSelected = _activeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> users) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải danh sách tài khoản...',
                style: TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 10),
              Text(
                'Lỗi tải dữ liệu: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _activeFilter == _ManagerFilter.unassigned
                    ? Icons.assignment_turned_in_outlined
                    : Icons.person_search_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                _activeFilter == _ManagerFilter.unassigned
                    ? 'Hiện không có Quản lý cơ sở nào đang rảnh (chưa phụ trách cơ sở nào).'
                    : 'Không tìm thấy tài khoản phù hợp với tìm kiếm.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_activeFilter == _ManagerFilter.unassigned) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 36),
                  ),
                  onPressed: () {
                    setState(() {
                      _activeFilter = _ManagerFilter.allFacilityManagers;
                    });
                  },
                  child: const Text('Xem tất cả Quản lý cơ sở'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currentManagerCount = _allUsers
        .where((u) => _getAssignmentInfo(u).isAssignedToThis)
        .length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: users.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildFacilityStatusBanner(currentManagerCount);
        }
        final u = users[index - 1];
        return _buildUserCard(u);
      },
    );
  }

  Widget _buildFacilityStatusBanner(int count) {
    if (count == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cơ sở "${widget.facilityName}" hiện chưa có người quản lý phụ trách.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded,
              size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cơ sở "${widget.facilityName}" đang có $count người phụ trách quản lý.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final userId = u['id']?.toString() ?? '';
    final name = u['fullName']?.toString() ??
        u['username']?.toString() ??
        'Chưa đặt tên';
    final username = u['username']?.toString() ?? '';
    final email = u['email']?.toString() ?? '';
    final phone = u['phone']?.toString() ?? '';
    final rawRole = _getRawRole(u);
    final roleLabel = ViLabels.role(rawRole);
    final isMgr = _isFacilityManager(u);
    final info = _getAssignmentInfo(u);
    final isAssigning = _assigningUserId == userId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.isAssignedToThis ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: info.isAssignedToThis
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
          width: info.isAssignedToThis ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Avatar + Name + Role Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: info.isAssignedToThis
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF334155),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMgr
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMgr
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (username.isNotEmpty) '@$username',
                        if (email.isNotEmpty) email,
                        if (phone.isNotEmpty) phone,
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Row: Facility status badge on the left, Action button on the right
          Row(
            children: [
              // Status Badge
              Expanded(
                child: info.isAssignedToThis
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 13, color: Color(0xFF15803D)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Đang quản lý: ${widget.facilityName}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : info.isUnassigned
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    size: 8, color: Color(0xFF059669)),
                                SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Chưa quản lý cơ sở nào (Sẵn sàng)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF047857),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 13, color: Color(0xFF475569)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: RichText(
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF475569)),
                                      children: [
                                        const TextSpan(text: 'Đang quản lý: '),
                                        TextSpan(
                                          text: info.facilityName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(width: 8),

              // Action button
              if (info.isAssignedToThis)
                TextButton.icon(
                  onPressed: isAssigning ? null : () => _handleUnassign(u),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.error,
                  ),
                  icon: isAssigning
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.remove_circle_outline, size: 14),
                  label: const Text(
                    'Gỡ quyền',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                )
              else if (info.isUnassigned)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isAssigning ? null : () => _handleAssign(u),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAssigning
                            ? Colors.grey.shade400
                            : const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isAssigning
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 13, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Gán',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                )
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isAssigning ? null : () => _handleAssign(u),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAssigning
                            ? Colors.grey.shade400
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isAssigning
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Chuyển',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

