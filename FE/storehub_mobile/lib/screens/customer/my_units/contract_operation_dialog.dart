import '../../../widgets/return_settlement_card.dart';
import '../payment/vnpay_checkout_screen.dart';
import 'package:flutter/material.dart';
import '../../../models/checkout_schedule_window.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/my_unit_model.dart';
import '../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatefulWidget {
  final MyUnitModel unit;
  final bool isExtension;
  final bool resumePending;

  /// true = khách bấm "Pay late fee": dialog tải khoản phí trễ hạn đang chờ
  /// (GET /payments/bookings/{id}/overdue) và cho thanh toán qua VNPay.
  final bool payOverdue;
  final StorageApiService? storageService;

  const ContractOperationDialog({
    super.key,
    required this.unit,
    required this.isExtension,
    this.resumePending = false,
    this.payOverdue = false,
    this.storageService,
  });

  @override
  State<ContractOperationDialog> createState() =>
      _ContractOperationDialogState();
}

class _ContractOperationDialogState extends State<ContractOperationDialog> {
  late final StorageApiService _storageService =
      widget.storageService ?? StorageApiService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _bankCodeController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy • HH:mm');

  int _extraMonths = 3;
  DateTime? _scheduledReturnTime;
  String? _timeValidationError;
  String? _bankError;
  String? _accountNumberError;
  String? _accountNameError;
  bool _isLoading = false;
  bool _isResuming = false;
  bool _isCancellingExtension = false;
  String? _resumeError;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _paymentConfirmed;

  static const List<String> _popularBanks = [
    'MBBank',
    'Vietcombank',
    'Techcombank',
    'BIDV',
    'ACB',
    'VietinBank',
    'VPBank',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.payOverdue) {
      _loadOverduePayment();
    } else if (widget.resumePending) {
      _loadPendingExtensionPayment();
    } else if (!widget.isExtension) {
      _bankCodeController.text = widget.unit.refundBankCode;
      _accountNumberController.text = widget.unit.refundAccountNumber;
      _accountNameController.text = widget.unit.refundAccountName;
      _notesController.text = widget.unit.checkoutNotes;
      if (widget.unit.scheduledReturnTime != null) {
        _scheduledReturnTime = widget.unit.scheduledReturnTime;
        _timeValidationError = _checkoutWindow.validate(
            _scheduledReturnTime!,
            CheckoutScheduleWindow.vietnamNow(),
            widget.unit.openTime,
            widget.unit.closeTime);
        return;
      }
      final now = CheckoutScheduleWindow.vietnamNow();
      final openH = widget.unit.openHour;
      final closeH = widget.unit.closeHour;
      if (now.hour < closeH) {
        int targetHour;
        if (now.hour < openH) {
          targetHour = (openH <= 9 && closeH >= 9) ? 9 : openH;
        } else {
          targetHour = now.minute >= 45 ? now.hour + 2 : now.hour + 1;
          if (targetHour >= closeH) {
            targetHour = closeH;
          }
        }
        _scheduledReturnTime = DateTime(
          now.year,
          now.month,
          now.day,
          targetHour,
          0,
        );
      } else {
        final tomorrow = now.add(const Duration(days: 1));
        final defaultHour = (openH <= 9 && closeH >= 9) ? 9 : openH;
        _scheduledReturnTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          defaultHour,
          0,
        );
      }
      if (_scheduledReturnTime!.isBefore(_checkoutWindow.earliest)) {
        final day = _checkoutWindow.earliest;
        _scheduledReturnTime = DateTime(day.year, day.month, day.day, openH);
      }
      _timeValidationError = _checkoutWindow.validate(_scheduledReturnTime!,
          now, widget.unit.openTime, widget.unit.closeTime);
    }
  }

  CheckoutScheduleWindow get _checkoutWindow =>
      CheckoutScheduleWindow.forRental(
          widget.unit.endDate,
          widget.unit.agreement.policy.returnNoticeDays,
          CheckoutScheduleWindow.vietnamNow());

  String get _returnRefundDeadlineText {
    final days = widget.unit.agreement.policy.refundSlaDays;
    return days == null
        ? 'Tiền cọc được xử lý hoàn theo thời hạn trong hợp đồng sau khi nhân viên xác nhận nhận lại kho và đối soát khấu trừ.'
        : 'Tiền cọc được xử lý hoàn trong tối đa $days ngày kể từ khi nhân viên xác nhận hoàn tất nhận lại kho, sau đối soát công nợ và khấu trừ theo hợp đồng.';
  }

  Future<void> _loadOverduePayment() async {
    setState(() {
      _isResuming = true;
      _resumeError = null;
    });
    try {
      final payment =
          await _storageService.getPendingOverduePayment(widget.unit.bookingId);
      if (!mounted) return;
      if (payment == null) {
        setState(() {
          _isResuming = false;
          _resumeError = 'Ngăn kho này không còn phí trễ hạn.';
        });
        return;
      }
      if (payment['status'] == 'PAID') {
        setState(() {
          _isResuming = false;
          _paymentConfirmed = payment;
          _result = {'paymentRequired': false};
        });
        return;
      }
      setState(() {
        _isResuming = false;
        _result = {
          'paymentRequired': true,
          'transactionId': payment['transactionId'],
          'qrCodeUrl': payment['qrCodeUrl'],
          'additionalFee': payment['amount'],
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _resumeError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Hủy yêu cầu gia hạn đang chờ thanh toán để khách không bị kẹt ở trạng thái "pending".
  Future<void> _cancelExtension() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy yêu cầu gia hạn?'),
        content: const Text(
          'Yêu cầu gia hạn sẽ bị hủy. Nếu VNPay vẫn thu tiền '
          'từ liên kết cũ, hệ thống sẽ yêu cầu hoàn tiền. '
          'Sau đó bạn có thể yêu cầu gia hạn mới.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCancellingExtension = true);
    try {
      await _storageService.cancelPendingExtension(widget.unit.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy yêu cầu gia hạn'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancellingExtension = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadPendingExtensionPayment() async {
    setState(() {
      _isResuming = true;
      _resumeError = null;
    });
    try {
      final payment = await _storageService
          .getPendingExtensionPayment(widget.unit.bookingId);
      if (!mounted) return;
      if (payment == null) {
        setState(() {
          _isResuming = false;
          _resumeError =
              'Không còn khoản gia hạn nào đang chờ thanh toán cho ngăn kho này.';
        });
        return;
      }
      if (payment['status'] == 'PAID') {
        setState(() {
          _isResuming = false;
          _paymentConfirmed = payment;
          _result = {'paymentRequired': false};
        });
        return;
      }
      setState(() {
        _isResuming = false;
        _result = {
          'paymentRequired': true,
          'transactionId': payment['transactionId'],
          'qrCodeUrl': payment['qrCodeUrl'],
          'additionalFee': payment['amount'],
          'newEndDate':
              widget.unit.pendingNewEndDate?.toIso8601String().substring(0, 10),
          'updatedTotalFee': widget.unit.totalRentalFee +
              (widget.unit.pendingExtensionFee ?? 0),
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _resumeError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _setScheduledTime(DateTime dt) {
    final minuteFraction = dt.minute / 60.0;
    final totalHours = dt.hour + minuteFraction;
    final openH = widget.unit.openHour.toDouble();
    final closeH = widget.unit.closeHour.toDouble();

    String? error = _checkoutWindow.validate(
        dt,
        CheckoutScheduleWindow.vietnamNow(),
        widget.unit.openTime,
        widget.unit.closeTime);
    if (totalHours < openH || totalHours > closeH) {
      final hourStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      error =
          'Giờ hẹn ($hourStr) nằm ngoài khung giờ mở cửa (${widget.unit.operatingHours}). Vui lòng chọn giờ trong khung giờ này.';
    } else if (!dt.isAfter(CheckoutScheduleWindow.vietnamNow())) {
      error = 'Giờ hẹn trả kho phải ở thời điểm tương lai.';
    }

    setState(() {
      _scheduledReturnTime = dt;
      _timeValidationError = error;
    });
  }

  List<TimeOfDay> get _suggestedTimeSlots {
    final defaultSlots = <TimeOfDay>[
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
    ];
    return defaultSlots.where((s) {
      final h = s.hour + s.minute / 60.0;
      return h >= widget.unit.openHour && h <= widget.unit.closeHour;
    }).toList();
  }

  Future<void> _pickScheduledReturnTime() async {
    final now = CheckoutScheduleWindow.vietnamNow();
    final window = _checkoutWindow;
    final initialDate = _scheduledReturnTime ?? now;
    final initialDay =
        DateTime(initialDate.year, initialDate.month, initialDate.day);
    final date = await showDatePicker(
      context: context,
      initialDate: initialDay.isBefore(window.earliest)
          ? window.earliest
          : initialDay.isAfter(window.latest)
              ? window.latest
              : initialDay,
      firstDate: window.earliest,
      lastDate: window.latest,
      helpText: 'CHỌN NGÀY HẸN TRẢ KHO',
    );
    if (date == null || !mounted) return;

    final initialHour = _scheduledReturnTime?.hour ??
        ((widget.unit.openHour <= 9 && widget.unit.closeHour >= 9)
            ? 9
            : widget.unit.openHour);
    final initialMinute = _scheduledReturnTime?.minute ?? 0;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      helpText: 'CHỌN GIỜ HẸN TRẢ KHO (${widget.unit.operatingHours})',
    );
    if (time == null) return;

    _setScheduledTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _submitAction() async {
    if (!widget.isExtension) {
      if (_scheduledReturnTime != null) {
        setState(() => _timeValidationError = _checkoutWindow.validate(
            _scheduledReturnTime!,
            CheckoutScheduleWindow.vietnamNow(),
            widget.unit.openTime,
            widget.unit.closeTime));
      }
      if (_scheduledReturnTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ngày giờ hẹn trả kho.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_timeValidationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_timeValidationError!),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final bank = _bankCodeController.text.trim();
      final accountNum = _accountNumberController.text.trim();
      final accountName = _accountNameController.text.trim();

      String? bankErr;
      String? numErr;
      String? nameErr;

      if (bank.isEmpty) {
        bankErr = 'Vui lòng chọn hoặc nhập tên ngân hàng';
      }
      if (accountNum.isEmpty) {
        numErr = 'Vui lòng nhập số tài khoản';
      } else if (accountNum.length < 6) {
        numErr = 'Số tài khoản không hợp lệ (tối thiểu 6 ký tự)';
      }
      if (accountName.isEmpty) {
        nameErr = 'Vui lòng nhập tên chủ tài khoản';
      }

      if (bankErr != null || numErr != null || nameErr != null) {
        setState(() {
          _bankError = bankErr;
          _accountNumberError = numErr;
          _accountNameError = nameErr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Vui lòng nhập đầy đủ thông tin tài khoản nhận hoàn cọc.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result;
      if (widget.isExtension) {
        result = await _storageService.extendRental(
            widget.unit.bookingId, _extraMonths);
      } else {
        result = await _storageService.checkoutRental(
          widget.unit.bookingId,
          _scheduledReturnTime!,
          notes: _notesController.text.trim(),
          bankCode: _bankCodeController.text.trim(),
          bankAccountNumber: _accountNumberController.text.trim(),
          bankAccountName: _accountNameController.text.trim(),
        );
      }

      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _needsExtensionPayment =>
      (widget.isExtension || widget.payOverdue) &&
      _result != null &&
      _result!['paymentRequired'] == true &&
      _paymentConfirmed == null;

  /// Mở VNPay trong app. Giao dịch chỉ thành PAID khi VNPay gọi về server;
  /// khách không thể tự bấm "đã trả".
  Future<void> _payWithVnpay() async {
    // Re-read the attempt: a previously displayed URL can have expired.
    try {
      if (widget.payOverdue) {
        await _loadOverduePayment();
      } else {
        await _loadPendingExtensionPayment();
      }
    } catch (_) {
      return;
    }
    if (!mounted || _paymentConfirmed != null || _resumeError != null) return;
    final result = _result;
    if (result == null) return;
    final transactionId = result['transactionId']?.toString() ?? '';
    final paymentUrl =
        (result['paymentUrl'] ?? result['qrCodeUrl'])?.toString() ?? '';
    if (transactionId.isEmpty || paymentUrl.isEmpty) return;
    final fee = num.tryParse(result['additionalFee']?.toString() ?? '') ?? 0;

    final paid = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => VnpayCheckoutScreen(
          paymentUrl: paymentUrl,
          transactionId: transactionId,
          amount: fee.toDouble(),
          title: widget.payOverdue ? 'Phí trễ hạn • VNPay' : 'Gia hạn • VNPay',
          fetchStatus: _storageService.getPaymentStatus,
        ),
      ),
    );
    if (!mounted) return;
    if (paid != null) {
      setState(() => _paymentConfirmed = paid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resuming = widget.resumePending || widget.payOverdue;
    if (resuming && _isResuming) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (resuming && _resumeError != null) {
      return AlertDialog(
        title: Text(widget.payOverdue
            ? 'Không tải được phí trễ hạn'
            : 'Không thể tiếp tục thanh toán'),
        content: Text(_resumeError!, style: const TextStyle(fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      );
    }
    if (_needsExtensionPayment) {
      return _buildExtensionPaymentDialog();
    }
    if (_result != null) {
      return _buildResultDialog();
    }

    final titleWidget = widget.isExtension
        ? const Text('Gia hạn thuê')
        : Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_return_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    widget.unit.scheduledReturnTime == null
                        ? 'Yêu cầu trả kho'
                        : 'Đổi lịch trả kho',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: titleWidget,
      content: SingleChildScrollView(
        child: widget.isExtension ? _buildExtendForm() : _buildCheckoutForm(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: (_isLoading ||
                  (!widget.isExtension && _timeValidationError != null))
              ? null
              : _submitAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  widget.isExtension
                      ? 'Gia hạn'
                      : widget.unit.scheduledReturnTime == null
                          ? 'Xác nhận trả kho'
                          : 'Cập nhật lịch trả kho',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildExtendForm() {
    final unit = widget.unit;
    final monthlyPrice = unit.monthlyRate ??
        (unit.totalRentalFee > 0 && (unit.rentalMonths ?? 0) > 0
            ? unit.totalRentalFee / unit.rentalMonths!
            : 0.0);
    final estimatedFee = monthlyPrice * _extraMonths;
    final projectedEndDate = unit.endDate != null
        ? DateTime(
            unit.endDate!.year,
            unit.endDate!.month + _extraMonths,
            unit.endDate!.day,
          )
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Thẻ thông tin ngăn kho & thời hạn hiện tại
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warehouse_outlined,
                            size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ngăn ${unit.unitCode}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  if (monthlyPrice > 0)
                    Text(
                      '${_currency.format(monthlyPrice)} / tháng',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hạn hiện tại:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(
                    unit.endDate != null
                        ? _dateFmt.format(unit.endDate!)
                        : 'Chưa xác định',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (projectedEndDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hạn mới sau gia hạn:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600)),
                    Text(
                      _dateFmt.format(projectedEndDate),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Chọn thời gian gia hạn
        const Text(
          'Chọn thời gian gia hạn thêm:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 2, 3, 6, 12].map((m) {
            final selected = _extraMonths == m;
            return ChoiceChip(
              label: Text('+$m tháng'),
              selected: selected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
              onSelected: (_) => setState(() => _extraMonths = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Stepper tùy chỉnh số tháng
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Số tháng tùy chọn:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    color: _extraMonths > 1
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    onPressed: _extraMonths > 1
                        ? () => setState(() => _extraMonths--)
                        : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 70),
                    alignment: Alignment.center,
                    child: Text(
                      '$_extraMonths tháng',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    color: _extraMonths < 36
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    onPressed: _extraMonths < 36
                        ? () => setState(() => _extraMonths++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tạm tính chi phí
        if (estimatedFee > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tạm tính phí gia hạn:',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w600)),
                Text(
                  _currency.format(estimatedFee),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCheckoutForm() {
    final unit = widget.unit;
    final currentDateStr = _scheduledReturnTime != null
        ? _dateTimeFmt.format(_scheduledReturnTime!)
        : 'Chưa chọn thời gian';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thẻ thông tin ngăn kho & cơ sở
        Text(
            'Tiền cọc đang giữ: ${_currency.format(unit.depositPaid ?? 0)}. '
            'Trả đúng hạn hoặc trong thời gian ân hạn không bị tính phí trễ. '
            'Phí trễ tính theo ngày, sau ${unit.agreement.policy.graceDays ?? 0} ngày ân hạn'
            '${unit.agreement.policy.dailyLateFee == null ? ', theo hợp đồng.' : ': ${_currency.format(unit.agreement.policy.dailyLateFee)} / ngày.'} '
            'Ngày hết hạn vẫn được sử dụng hết ngày. Staff chốt phí khi nhận lại kho; tiền cọc được hoàn sau đối soát và khấu trừ hợp lệ.',
            style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.warehouse_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ngăn ${unit.unitCode}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          unit.operatingHours,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                unit.dimensions.isNotEmpty
                    ? '${unit.typeName} • ${unit.dimensions}'
                    : unit.typeName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Chính sách & Dự tính hoàn tiền khi trả kho
        _buildRefundPolicyCard(unit),
        const SizedBox(height: 16),

        // 2. Khối chọn ngày giờ hẹn trả kho
        const Row(
          children: [
            Icon(Icons.event_available_outlined,
                size: 17, color: AppColors.primary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '1. Chọn ngày & giờ hẹn trả kho',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Được chọn từ ${_dateFmt.format(_checkoutWindow.earliest)} đến ${_dateFmt.format(_checkoutWindow.latest)}, trong giờ ${unit.operatingHours}. '
          'Báo trước được rút ngắn khi gần hết hạn và không áp dụng khi đã quá hạn. '
          'Cần trả muộn hơn, vui lòng liên hệ cơ sở hoặc gia hạn.\n'
          'Đặt lịch chưa được tính là đã trả kho. Phí trễ hạn vẫn tính theo chính sách đến khi nhân viên xác nhận nhận lại kho. '
          'Đổi lịch không dời mốc khóa PIN hoặc chờ duyệt niêm phong. Nếu đã khóa PIN/niêm phong, hãy phối hợp với cơ sở và nhân viên để bàn giao.',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Nút chọn ngày giờ lớn
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _pickScheduledReturnTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _timeValidationError != null
                    ? AppColors.error
                    : AppColors.outline.withValues(alpha: 0.5),
                width: _timeValidationError != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: _timeValidationError != null
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentDateStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: _timeValidationError != null
                          ? AppColors.error
                          : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đổi ngày/giờ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quick time slot pills
        if (_suggestedTimeSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestedTimeSlots.map((slot) {
                final isSelected = _scheduledReturnTime != null &&
                    _scheduledReturnTime!.hour == slot.hour &&
                    _scheduledReturnTime!.minute == slot.minute;
                final slotText =
                    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(slotText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        )),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (!selected) return;
                      final base = _scheduledReturnTime ?? DateTime.now();
                      _setScheduledTime(DateTime(base.year, base.month,
                          base.day, slot.hour, slot.minute));
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Lỗi cảnh báo ngoài khung giờ
        if (_timeValidationError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _timeValidationError!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 3. Khối thông tin ngân hàng hoàn cọc (Tùy chọn)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 17, color: Colors.blue.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '2. Tài khoản nhận hoàn cọc (Bắt buộc)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Khoản tiền cọc sẽ được chuyển về tài khoản này sau khi nghiệm thu trả kho thành công:',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              // Gợi ý ngân hàng nhanh
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _popularBanks.map((bank) {
                    final selected = _bankCodeController.text == bank;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _bankCodeController.text = bank;
                            _bankError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                selected ? Colors.blue.shade800 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue.shade800
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            bank,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _bankCodeController,
                decoration: InputDecoration(
                  labelText: 'Ngân hàng * (VD: MBBank, Vietcombank)',
                  prefixIcon:
                      const Icon(Icons.account_balance_outlined, size: 18),
                  isDense: true,
                  errorText: _bankError,
                ),
                onChanged: (_) {
                  if (_bankError != null) setState(() => _bankError = null);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  labelText: 'Số tài khoản *',
                  prefixIcon: const Icon(Icons.numbers, size: 18),
                  isDense: true,
                  errorText: _accountNumberError,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_accountNumberError != null) {
                    setState(() => _accountNumberError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  labelText: 'Tên chủ tài khoản *',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  isDense: true,
                  errorText: _accountNameError,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_accountNameError != null) {
                    setState(() => _accountNameError = null);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. Ghi chú
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú cho nhân viên cơ sở (không bắt buộc)',
            prefixIcon: Icon(Icons.edit_note, size: 20),
            hintText: 'Ví dụ: Đã dọn dẹp xong, cần hỗ trợ mở cửa...',
            isDense: true,
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 12),

        // 5. Quy trình tóm tắt 3 bước
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quy trình: 1. Hẹn giờ -> 2. Nghiệm thu tại kho -> 3. Hoàn cọc trong 3-5 ngày',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefundPolicyCard(MyUnitModel unit) =>
      ReturnSettlementCard(settlement: unit.returnSettlement);

  Widget _buildExtensionPaymentDialog() {
    final result = _result!;
    final transactionId = result['transactionId']?.toString() ?? '';
    final fee = num.tryParse(result['additionalFee']?.toString() ?? '') ?? 0;
    final unit = widget.unit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header icon + Title + Close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (widget.payOverdue
                            ? AppColors.error
                            : AppColors.primary)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.payOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.autorenew_rounded,
                    color:
                        widget.payOverdue ? AppColors.error : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.payOverdue
                            ? (widget.isExtension
                                ? 'Đối soát gia hạn'
                                : 'Đối soát trả kho')
                            : 'Thanh toán phí gia hạn',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ngăn ${unit.unitCode} • ${unit.facilityName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isCancellingExtension
                      ? null
                      : () => Navigator.pop(context, true),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Fee Invoice Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    widget.payOverdue
                        ? 'Tổng phí trễ hạn'
                        : 'Số tiền thanh toán gia hạn',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currency.format(fee),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: widget.payOverdue
                          ? AppColors.error
                          : AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  if (transactionId.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mã giao dịch:',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            transactionId,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!widget.payOverdue && unit.endDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hạn hợp đồng hiện tại:',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          _dateFmt.format(unit.endDate!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Information Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.payOverdue
                          ? 'Thanh toán phí trễ hạn để khôi phục quyền truy cập kho.'
                          : 'Hợp đồng sẽ được tự động kích hoạt và kéo dài thời hạn ngay khi hoàn tất thanh toán VNPay.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF166534),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pay with VNPay Button
            ElevatedButton(
              onPressed: _isCancellingExtension ? null : _payWithVnpay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005BAA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Thanh toán qua VNPay',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Actions Row
            Row(
              children: [
                if (!widget.payOverdue)
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isCancellingExtension ? null : _cancelExtension,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: _isCancellingExtension
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Hủy yêu cầu này',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                if (!widget.payOverdue) const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _isCancellingExtension
                        ? null
                        : () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Đóng (để sau)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDialog() {
    final result = _result!;

    if (!widget.isExtension && !widget.payOverdue) {
      return AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Expanded(
                child: Text(
              'Đã hẹn trả kho thành công',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yêu cầu trả kho của bạn đã được ghi nhận. Vui lòng có mặt tại cơ sở theo lịch hẹn để cùng nhân viên nghiệm thu bàn giao. Tiền cọc được xử lý hoàn theo thời hạn trong hợp đồng sau khi hoàn tất nhận lại kho.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _resultRow('Ngăn kho', 'Ngăn ${widget.unit.unitCode}'),
                  if (_scheduledReturnTime != null)
                    _resultRow('Thời gian hẹn',
                        _dateTimeFmt.format(_scheduledReturnTime!)),
                  _resultRow('Cơ sở', widget.unit.facilityName),
                  _resultRow(
                    'Cọc dự kiến hoàn nếu trả hôm nay',
                    widget.unit.returnSettlement == null
                        ? 'Chờ đối soát từ máy chủ'
                        : _currency.format(
                            widget.unit.returnSettlement!.depositRefund),
                  ),
                  _resultRow(
                    'Tài khoản hoàn cọc',
                    '${_bankCodeController.text.trim()} • ${_accountNumberController.text.trim()}',
                  ),
                  if (_accountNameController.text.trim().isNotEmpty)
                    _resultRow(
                      'Chủ tài khoản',
                      _accountNameController.text.trim().toUpperCase(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_returnRefundDeadlineText Tiền thuê trọn kỳ không hoàn lại.',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.outline,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Đã hiểu & Về danh sách'),
          ),
        ],
      );
    }

    final message = widget.payOverdue
        ? (widget.unit.isReturnSettlement
            ? 'Đã thanh toán khoản phí trả kho. Tiền cọc được đối soát và xử lý hoàn theo hợp đồng; không phát sinh thêm phí sau khi nhân viên nhận lại kho.'
            : 'Đã đối soát phí phát sinh. Bạn có thể tiếp tục gia hạn thuê.')
        : (widget.isExtension && _paymentConfirmed != null)
            ? 'Đã xác nhận thanh toán. Hợp đồng của bạn đã được gia hạn.'
            : result['message']?.toString();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 8),
          Text('Đã ghi nhận yêu cầu'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message.isNotEmpty) ...[
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (widget.isExtension) ...[
            if (result['newEndDate'] != null)
              _resultRow('Ngày hết hạn mới', result['newEndDate'].toString()),
            if (result['additionalFee'] != null)
              _resultRow(
                'Phí phát sinh',
                _currency.format(
                    num.tryParse(result['additionalFee'].toString()) ?? 0),
              ),
            if (result['updatedTotalFee'] != null)
              _resultRow(
                'Tổng tiền thuê mới',
                _currency.format(
                    num.tryParse(result['updatedTotalFee'].toString()) ?? 0),
              ),
          ] else if (widget.payOverdue) ...[
            if (result['additionalFee'] != null)
              _resultRow(
                'Đã thanh toán phí trễ hạn',
                _currency.format(
                    num.tryParse(result['additionalFee'].toString()) ?? 0),
              ),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xong'),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
