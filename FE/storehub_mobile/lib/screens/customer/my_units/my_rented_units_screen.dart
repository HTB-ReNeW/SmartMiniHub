import '../../../widgets/return_settlement_card.dart';
import 'refund_account_dialog.dart';
import '../../../widgets/rental_agreement_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/vi_labels.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../widgets/logout_dialog.dart';
import '../../../services/storage_api_service.dart';
import '../../../models/my_unit_model.dart';
import '../../../widgets/state_views.dart';
import '../tickets/create_ticket_screen.dart';
import 'contract_operation_dialog.dart';
import 'smart_key_screen.dart';
import '../../../models/facility_operations_models.dart';
import '../../../widgets/photo_preview_dialog.dart';
import '../../../widgets/facility_contact_card.dart';

class MyRentedUnitsScreen extends StatefulWidget {
  final StorageApiService? storageService;
  const MyRentedUnitsScreen({super.key, this.storageService});

  @override
  State<MyRentedUnitsScreen> createState() => _MyRentedUnitsScreenState();
}

class _MyRentedUnitsScreenState extends State<MyRentedUnitsScreen>
    with WidgetsBindingObserver {
  late final StorageApiService _storageService =
      widget.storageService ?? StorageApiService();
  final BookingApiService _bookingService = BookingApiService();
  late Future<({List<MyUnitModel> active, List<MyUnitModel> awaiting})>
      _unitsFuture;
  bool _showAwaiting = false;
  final _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy • HH:mm');

  // Chỉ gia hạn khi đã nhận kho; nếu đang treo yêu cầu gia hạn thì vẫn cho mở lại
  // để thanh toán/hủy; nợ phí trễ hạn thì phải trả trước. Khách hàng có thể gia hạn bất kỳ lúc nào.
  bool _canExtend(MyUnitModel unit) => unit.isActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnits();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUnits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadUnits() {
    setState(() {
      _unitsFuture = _fetchUnits();
    });
  }

  Future<({List<MyUnitModel> active, List<MyUnitModel> awaiting})>
      _fetchUnits() async {
    final results = await Future.wait([
      _storageService.getMyRentedUnits(),
      _storageService.getAwaitingHandover(),
    ]);
    List<MyUnitModel> parse(List<dynamic> items) => items
        .map((item) =>
            MyUnitModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return (
      active: parse(results[0]),
      awaiting: parse(results[1]).where((unit) => !unit.isRefunded).toList()
    );
  }

  void _showRentalContract(MyUnitModel unit) {
    String date(DateTime? value) =>
        value == null ? 'Chưa có thông tin' : _dateFmt.format(value);
    final fields = <(String, String)>[
      ('Mã đơn thuê', unit.bookingCode),
      ('Khách hàng', unit.customerName),
      ('Ngăn kho', unit.displayUnit),
      ('Cơ sở', unit.facilityName),
      ('Địa chỉ', unit.facilityAddress),
      ('Loại kho', unit.typeName),
      ('Kích thước', unit.dimensions),
      ('Ngày bắt đầu thuê', date(unit.startDate)),
      ('Ngày hết hạn', date(unit.endDate)),
      (
        'Trạng thái',
        unit.isRefunded ? 'Đã hoàn tiền' : ViLabels.booking(unit.status)
      ),
      ('Tổng tiền thuê', _currency.format(unit.totalRentalFee)),
      if (unit.depositPaid != null)
        ('Tiền cọc đã thanh toán', _currency.format(unit.depositPaid)),
      (
        'Phí dịch vụ',
        unit.serviceFee == null
            ? 'Chưa có thông tin'
            : _currency.format(unit.serviceFee)
      ),
    ];
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => RentalAgreementScreen(
                fields: fields, agreement: unit.agreement)));
  }

  void _showUnitActions(MyUnitModel unit) {
    if (unit.isRefunded || unit.hasReturned) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.displayUnit,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (unit.facilityName.isNotEmpty)
                            Text(
                              unit.facilityName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('Hợp đồng & Cam kết lưu kho',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Xem điều khoản và cam kết đã xác nhận',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRentalContract(unit);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key, color: AppColors.primary),
                ),
                title: const Text('Khóa thông minh ngăn kho',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: unit.hasActiveAccess,
                subtitle: Text(
                  !unit.hasActiveAccess
                      ? (unit.accessDisabled
                          ? 'Đã khóa truy cập vì quá hạn thuê'
                          : 'Dùng được sau khi nhân viên bàn giao tại cơ sở')
                      : 'Mở / đóng khóa ngăn kho bằng mã PIN 6 số',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: unit.hasActiveAccess
                    ? () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SmartKeyScreen(
                              bookingId: unit.bookingId,
                              unitNumber: unit.unitCode,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.update, color: AppColors.primary),
                ),
                title: const Text('Gia hạn thuê',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: _canExtend(unit),
                subtitle: !unit.isActive
                    ? const Text(
                        'Dùng được sau khi nhân viên bàn giao tại cơ sở',
                        style: TextStyle(fontSize: 12))
                    : unit.hasPendingExtension
                        ? const Text(
                            'Tiếp tục hoặc hủy yêu cầu gia hạn đang chờ thanh toán',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary))
                        : unit.hasLateFeeDue
                            ? const Text(
                                'Đối soát phí phát sinh trong luồng gia hạn',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.error))
                            : const Text(
                                'Gia hạn thêm thời gian thuê bất cứ lúc nào',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant)),
                onTap: _canExtend(unit)
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(
                          unit,
                          isExtension: true,
                          payOverdue: unit.hasLateFeeDue,
                          resumePending: unit.hasPendingExtension,
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.error),
                ),
                title: Text(
                    unit.scheduledReturnTime != null
                        ? 'Đổi lịch trả kho'
                        : 'Yêu cầu trả kho',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: unit.isActive,
                subtitle: unit.isActive
                    ? (unit.scheduledReturnTime != null
                        ? Text(
                            'Hiện tại: ${_dateTimeFmt.format(unit.scheduledReturnTime!)}',
                            style: const TextStyle(fontSize: 12))
                        : null)
                    : const Text(
                        'Dùng được sau khi nhân viên bàn giao tại cơ sở',
                        style: TextStyle(fontSize: 12)),
                onTap: unit.isActive
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(unit, isExtension: false);
                      }
                    : null,
              ),
              if (unit.status == 'CONFIRMED')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cancel_outlined,
                        color: AppColors.error),
                  ),
                  title: const Text('Hủy đơn',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                      unit.hasHandoverIssue
                          ? 'Hủy do lỗi cơ sở: hoàn toàn bộ tiền đã thu'
                          : 'Tiền cọc được hoàn theo chính sách hủy của cơ sở',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancelBooking(unit);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_edu_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('Biên bản bàn giao & ảnh',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                    'Xem tình trạng & ảnh lúc bàn giao/trả kho',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCustomerHandoverHistory(unit);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_outlined,
                      color: AppColors.secondary),
                ),
                title: const Text('Báo sự cố',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTicketScreen(
                        preselectedBookingId: unit.bookingId,
                        preselectedUnitLabel:
                            '${unit.displayUnit} • ${unit.facilityName}',
                      ),
                    ),
                  );
                  if (result == true) _loadUnits();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomerHandoverHistory(MyUnitModel unit) async {
    final historyFuture =
        _storageService.getCustomerHandoverRecords(unit.bookingId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Quay lại',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.history_edu,
                        color: AppColors.primaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Biên bản bàn giao • Ngăn ${unit.unitCode}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<HandoverRecordModel>>(
                  future: historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingState(
                        message: 'Đang tải biên bản bàn giao...',
                      );
                    }
                    if (snapshot.hasError) {
                      return AppErrorState(
                        message: snapshot.error
                            .toString()
                            .replaceAll('Exception: ', ''),
                      );
                    }

                    final records = snapshot.data ?? <HandoverRecordModel>[];
                    if (records.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.history,
                        title: 'Chưa có biên bản bàn giao',
                        message:
                            'Biên bản bàn giao kèm ảnh sẽ hiển thị tại đây sau khi nhân viên bàn giao kho.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isCheckIn =
                            record.recordType.toUpperCase() == 'CHECK_IN';
                        final recordedTime = record.recordedAt == null
                            ? ''
                            : _dateTimeFmt.format(record.recordedAt!);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isCheckIn
                                          ? AppColors.success
                                              .withValues(alpha: 0.15)
                                          : AppColors.secondaryContainer
                                              .withValues(alpha: 0.15),
                                      child: Icon(
                                        isCheckIn ? Icons.login : Icons.logout,
                                        color: isCheckIn
                                            ? AppColors.success
                                            : AppColors.secondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCheckIn
                                                ? 'Biên bản bàn giao kho'
                                                : 'Biên bản nghiệm thu trả kho',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (recordedTime.isNotEmpty)
                                            Text(
                                              recordedTime,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (record.unitCondition.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Tình trạng: ${record.unitCondition}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (record.damageFee != null &&
                                    record.damageFee! > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Khấu trừ: ${_currency.format(record.damageFee)}${record.damageReason != null ? " (${record.damageReason})" : ""}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if (record.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Ghi chú: ${record.notes}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (record.staffName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Người kiểm tra: ${record.staffName}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant),
                                    ),
                                  ),
                                if (record.photos.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ảnh bằng chứng:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  PhotoThumbnailGrid(
                                      photos: record.photos, size: 70),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelBooking(MyUnitModel unit) async {
    Map<String, dynamic> quote;
    try {
      quote = await _bookingService.cancellationQuote(unit.bookingId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được số tiền hoàn: $e')));
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy đơn đặt kho?'),
        content: Text(
            'Tiền cọc hoàn: ${_currency.format(quote['depositRefund'])}\n'
            'Tiền thuê hoàn: ${_currency.format(quote['rentalRefund'])}\n'
            'Tổng dự kiến: ${_currency.format(quote['totalRefund'])}\n\n'
            'Mốc 24 giờ từ lúc đặt: ${DateTime.tryParse(quote['deadline'].toString()) != null ? _dateTimeFmt.format(DateTime.parse(quote['deadline'].toString())) : quote['deadline']}\n'
            'Máy chủ tính lại khi nhận yêu cầu hủy; tiền hoàn có thể thay đổi nếu vượt mốc 24 giờ. '
            'Sau khi hủy, đơn không còn được bàn giao.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ đơn'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Xác nhận hủy đơn lần cuối'),
              content: const Text(
                  'Bạn chắc chắn muốn hủy đơn này? Sau khi gửi yêu cầu, đơn không còn được bàn giao. Tiếp theo, hãy nhập tài khoản nhận hoàn tiền.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Giữ đơn')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Xác nhận & tiếp tục'))
              ],
            ));
    if (finalConfirm != true || !mounted) return;
    final sent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RefundAccountDialog(
            onSubmit: (account) => _bookingService.cancelWithRefundAccount(
                unit.bookingId, account)));
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Đã gửi yêu cầu hủy và thông tin tài khoản nhận hoàn tiền'),
        backgroundColor: AppColors.success));
    _loadUnits();
  }

  Future<void> _openContractOperation(
    MyUnitModel unit, {
    required bool isExtension,
    bool resumePending = false,
    bool payOverdue = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContractOperationDialog(
        unit: unit,
        isExtension: isExtension,
        resumePending: resumePending,
        payOverdue: payOverdue || unit.isReturnSettlement,
      ),
    );
    if (result == true) {
      _loadUnits();
    }
  }

  void _logout(BuildContext context) async {
    if (!await confirmLogout(context)) return;
    await AuthApiService().logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Color _statusColor(String status) {
    if (status == 'OVERDUE') return AppColors.error;
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'CONFIRMED':
        return AppColors.secondaryContainer;
      case 'PENDING_PAYMENT':
        return AppColors.warning;
      case 'COMPLETED':
        return AppColors.outline;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.outline;
    }
  }

  String _unitBadgeLabel(MyUnitModel unit) {
    if (unit.hasReturned) return 'Đã trả kho';
    if (unit.isRefunded) return 'Đã hoàn tiền';
    if (unit.status == 'CANCELLED') return 'Đã gửi yêu cầu hủy';
    if (unit.overdue) return 'Quá hạn';
    if (unit.isActive && unit.scheduledReturnTime != null) {
      return 'Đã hẹn trả kho';
    }
    return ViLabels.booking(unit.status);
  }

  Color _unitBadgeColor(MyUnitModel unit) {
    if (unit.isRefunded) return AppColors.success;
    if (unit.overdue) return AppColors.error;
    if (unit.isActive && unit.scheduledReturnTime != null) {
      return AppColors.warning;
    }
    return _statusColor(unit.status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kho của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnits,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadUnits(),
        child: FutureBuilder<
            ({List<MyUnitModel> active, List<MyUnitModel> awaiting})>(
          future: _unitsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Đang tải kho của bạn...');
            } else if (snapshot.hasError) {
              return ListView(
                children: [
                  AppErrorState(
                    message:
                        snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadUnits,
                  ),
                ],
              );
            }

            final active = snapshot.data?.active ?? <MyUnitModel>[];
            final awaiting = snapshot.data?.awaiting ?? <MyUnitModel>[];
            final units = _showAwaiting ? awaiting : active;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.warehouse_outlined,
                            color: AppColors.secondary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${active.where((unit) => unit.isActive).length} đang thuê'
                                  '${active.any((unit) => unit.hasReturned) ? ' • ${active.where((unit) => unit.hasReturned).length} đã trả' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const Text(' • ',
                                    style: TextStyle(color: Colors.white38)),
                                Text(
                                  '${awaiting.length} chờ nhận kho',
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showAwaiting
                                  ? 'Bạn đã thanh toán. Hãy đến đúng giờ hẹn để nhân viên bàn giao ngăn kho.'
                                  : 'Chạm vào ngăn kho để mở khóa thông minh hoặc quản lý hợp đồng.',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showAwaiting = false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: !_showAwaiting
                                  ? AppColors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 15,
                                    color: !_showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Flexible(
                                    child: Text(
                                  active.any((unit) => unit.hasReturned)
                                      ? 'Đang thuê / Đã trả (${active.length})'
                                      : 'Đang thuê (${active.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_showAwaiting
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: !_showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant,
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showAwaiting = true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _showAwaiting
                                  ? AppColors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule,
                                    size: 15,
                                    color: _showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Flexible(
                                    child: Text(
                                  'Chờ nhận (${awaiting.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _showAwaiting
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant,
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (units.isEmpty)
                  AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _showAwaiting
                        ? 'Chưa có lịch nhận kho'
                        : 'Chưa có kho đang thuê',
                    message: _showAwaiting
                        ? 'Booking đã thanh toán sẽ hiện ở đây cho đến khi nhân viên bàn giao.'
                        : 'Ngăn kho sẽ hiện ở đây sau khi nhân viên hoàn tất bàn giao.',
                  ),
                ...units.map((unit) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildUnitCard(unit),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnitCard(MyUnitModel unit) {
    final monthlyRate = unit.monthlyRate;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (unit.isRefunded || unit.hasReturned)
            ? null
            : unit.isReturnSettlement
                ? () => _openContractOperation(unit, isExtension: false)
                : () => _showUnitActions(unit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.displayUnit,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          unit.dimensions.isNotEmpty
                              ? '${unit.typeName} • ${unit.dimensions}'
                              : unit.typeName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _unitBadgeColor(unit).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _unitBadgeLabel(unit),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _unitBadgeColor(unit),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName.isNotEmpty
                          ? '${unit.facilityName}${unit.facilityAddress.isNotEmpty ? ', ${unit.facilityAddress}' : ''}'
                          : 'Chưa xác định cơ sở',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FacilityContactCard(
                  managerName: unit.facilityManagerName,
                  phone: unit.facilityContactPhone,
                  email: unit.facilityContactEmail),
              if (unit.isRefunded) ...[
                const SizedBox(height: 10),
                const Text('Cơ sở đã hoàn tất hoàn tiền cho đơn này.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
              if (unit.status == 'CANCELLED' && !unit.isRefunded) ...[
                const SizedBox(height: 10),
                const Text(
                    'Đã gửi yêu cầu hủy. Đơn không còn chờ bàn giao. '
                    'Khoản hoàn tiền (nếu có) được xử lý theo chính sách của cơ sở.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
              if (unit.hasHandoverIssue) ...[
                const SizedBox(height: 10),
                Text(
                    'Cơ sở đang xử lý sự cố bàn giao: ${unit.handoverIssueReason}',
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12)),
                Text(
                    'Hạn xử lý / chờ bàn giao: ${unit.handoverIssueDueAt.replaceAll('T', ' ')}',
                    style: const TextStyle(fontSize: 12)),
                const Text(
                    'Bạn không bị áp phí hủy do lỗi cơ sở. Nếu hủy trước khi nhận kho, hệ thống tạo yêu cầu hoàn toàn bộ tiền đã thu.',
                    style: TextStyle(fontSize: 12)),
              ],
              if (unit.overdue) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            'Hợp đồng đã quá hạn${unit.overdueDays > 0 ? ' ${unit.overdueDays} ngày' : ''}.',
                            if (unit.hasLateFeeDue)
                              'Phí trễ hạn dự kiến: ${_currency.format(unit.overdueFeeOutstanding)}.',
                            if (unit.accessDisabled)
                              'Khóa thông minh đã bị vô hiệu hóa.',
                            if (unit.hasLateFeeDue)
                              'Phí được chốt khi nhân viên nhận lại kho, theo chính sách hợp đồng.',
                            if (unit.scheduledReturnTime == null)
                              'Vui lòng gia hạn thuê hoặc gửi yêu cầu trả kho.'
                            else
                              'Bạn đã gửi yêu cầu trả kho. Vui lòng bàn giao theo lịch hẹn.',
                          ].join(' '),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.isActive && unit.scheduledReturnTime != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Hẹn trả kho lúc ${_dateTimeFmt.format(unit.scheduledReturnTime!)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.hasPendingExtension) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unit.pendingExtensionFee != null
                              ? 'Yêu cầu gia hạn ${unit.pendingExtraMonths ?? '?'} tháng đang chờ thanh toán '
                                  '(${_currency.format(unit.pendingExtensionFee)}). Chạm "Gia hạn thuê" để thanh toán hoặc hủy yêu cầu.'
                              : 'Bạn có yêu cầu gia hạn đang chờ thanh toán.',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.status == 'CANCELLED') ...[
                const SizedBox(height: 12),
                Text(
                  'Tổng tiền sẽ hoàn: ${_currency.format(unit.totalRentalFee + (unit.depositPaid ?? 0))}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success),
                ),
              ] else if (monthlyRate != null) ...[
                const SizedBox(height: 12),
                Text('${_currency.format(monthlyRate)} / tháng',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày bắt đầu thuê',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                              unit.startDate != null
                                  ? _dateFmt.format(unit.startDate!)
                                  : 'Chưa có thông tin',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày hết hạn',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            unit.endDate != null
                                ? _dateFmt.format(unit.endDate!)
                                : '-',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showRentalContract(unit),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Hợp đồng & Cam kết'),
                ),
              ),
              if (unit.returnIsDue ||
                  unit.hasReturned ||
                  unit.scheduledReturnTime != null) ...[
                const SizedBox(height: 10),
                if (unit.hasReturned) ...[
                  ReturnSettlementCard(settlement: unit.returnSettlement),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: unit.hasReturned ||
                              unit.scheduledReturnTime != null
                          ? null
                          : () =>
                              _openContractOperation(unit, isExtension: false),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(unit.hasReturned
                          ? 'Đã trả kho'
                          : unit.scheduledReturnTime != null
                              ? 'Đã gửi yêu cầu trả kho'
                              : 'Trả kho'),
                    )),
                if (unit.isReturnSettlement)
                  SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            _openContractOperation(unit, isExtension: false),
                        child: const Text('Thanh toán phần còn thiếu'),
                      )),
              ],
              if (!unit.isRefunded && !unit.hasReturned) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: unit.hasActiveAccess
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SmartKeyScreen(
                                      bookingId: unit.bookingId,
                                      unitNumber: unit.unitCode,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.key, size: 16),
                        label: const Text('Mở khóa',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUnitActions(unit),
                        icon: const Icon(Icons.more_horiz, size: 16),
                        label: const Text('Quản lý',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
