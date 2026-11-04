import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/safe_dispose.dart';
import '../../models/rental_agreement.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/rental_agreement_screen.dart';
import '../../widgets/refund_review_widgets.dart';

class RefundDetailScreen extends StatefulWidget {
  final String facilityId;
  final Map<String, dynamic> initial;
  final FacilityOpsApiService service;
  const RefundDetailScreen(
      {super.key,
      required this.facilityId,
      required this.initial,
      required this.service});
  @override
  State<RefundDetailScreen> createState() => _RefundDetailScreenState();
}

class _RefundDetailScreenState extends State<RefundDetailScreen> {
  late RefundViewData _refund = RefundViewData(widget.initial);
  bool _loading = true, _busy = false;
  String? _error;
  String _lastReference = '', _lastNotes = '';
  bool get _enabled => !_loading && !_busy && _error == null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.service
          .getFacilityRefundDetail(widget.facilityId, _refund.text('id'));
      if (mounted) setState(() => _refund = RefundViewData(raw));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    if (!_enabled) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_error == null
                ? message
                : 'Thao tác đã được ghi nhận. Vui lòng tải lại trạng thái.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép số tài khoản.')));
    }
  }

  Future<void> _confirmTransfer() async {
    if (!_enabled || !_refund.canConfirm || !_refund.hasBank) return;
    final reference = TextEditingController(text: _lastReference),
        notes = TextEditingController(text: _lastNotes);
    final form = GlobalKey<FormState>();
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Xác nhận chuyển khoản hoàn tiền',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(refundMoney(_refund.raw['amount']),
                                    style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                        color: refundInk)),
                                const SizedBox(height: 12),
                                Text(
                                    '${_refund.text('bankCode')} · ${_refund.text('bankAccountNumber')}'),
                                const SizedBox(height: 5),
                                Text(_refund.text('bankAccountName'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                const Text(
                                    'Chỉ xác nhận sau khi đã chuyển đủ tiền đến tài khoản trên.',
                                    style: TextStyle(
                                        fontSize: 12, color: refundMuted)),
                                const SizedBox(height: 12),
                                TextFormField(
                                    key: const ValueKey('transfer-reference'),
                                    controller: reference,
                                    maxLength: 100,
                                    decoration: const InputDecoration(
                                        labelText: 'Mã giao dịch ngân hàng',
                                        hintText:
                                            'Nhập mã giao dịch chuyển khoản thực tế'),
                                    validator: (value) => value == null ||
                                            value.trim().isEmpty
                                        ? 'Vui lòng nhập mã giao dịch ngân hàng'
                                        : null),
                                TextFormField(
                                    controller: notes,
                                    maxLines: 2,
                                    maxLength: 1000,
                                    decoration: const InputDecoration(
                                        labelText: 'Ghi chú (tùy chọn)')),
                              ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Quay lại')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: refundInk,
                            foregroundColor: Colors.white),
                        child: const Text('Xác nhận hoàn tất'))
                  ]));
      if (confirmed != true || !mounted) return;
      _lastReference = reference.text.trim();
      _lastNotes = notes.text.trim();
      await _run(
          () => widget.service.confirmBankTransfer(
              widget.facilityId, _refund.text('id'),
              transferReference: reference.text.trim(),
              notes: notes.text.trim().isEmpty ? null : notes.text.trim()),
          'Đã xác nhận hoàn tiền thành công.');
    } finally {
      disposeAfterRouteCloses([reference, notes]);
    }
  }

  Future<void> _metadata() async {
    final date = TextEditingController(),
        number = TextEditingController(),
        amount = TextEditingController();
    final form = GlobalKey<FormState>();
    try {
      final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Bổ sung giao dịch gốc'),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text(
                                'Nhập đúng thông tin từ giao dịch VNPay gốc, không dùng ngày yêu cầu hoàn tiền.',
                                style: TextStyle(fontSize: 12)),
                            TextFormField(
                                controller: date,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Ngày giao dịch (yyyyMMddHHmmss)'),
                                validator: (v) => RegExp(r'^\d{14}$')
                                        .hasMatch(v?.trim() ?? '')
                                    ? null
                                    : 'Ngày giao dịch chưa hợp lệ'),
                            TextFormField(
                                controller: number,
                                decoration: const InputDecoration(
                                    labelText: 'Mã giao dịch VNPay (nếu có)')),
                            TextFormField(
                                controller: amount,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Số tiền giao dịch gốc (đ)'),
                                validator: (v) {
                                  final n = num.tryParse(v?.trim() ?? '');
                                  final due =
                                      num.tryParse(_refund.text('amount'));
                                  return n != null &&
                                          n.isFinite &&
                                          n > 0 &&
                                          due != null &&
                                          n >= due
                                      ? null
                                      : 'Số tiền phải lớn hơn hoặc bằng khoản hoàn';
                                }),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        child: const Text('Lưu thông tin'))
                  ]));
      if (ok == true && mounted) {
        await _run(
            () => widget.service.provideRefundDetails(
                widget.facilityId,
                _refund.text('id'),
                date.text.trim(),
                number.text.trim(),
                num.parse(amount.text.trim())),
            'Đã bổ sung thông tin giao dịch.');
      }
    } finally {
      disposeAfterRouteCloses([date, number, amount]);
    }
  }

  void _contract() {
    final q = _refund;
    final fields = <(String, String)>[
      ('Mã đơn thuê', q.text('bookingCode')),
      ('Khách hàng', q.info('customerName')),
      ('Email', q.info('customerEmail')),
      ('Cơ sở', q.info('facilityName')),
      ('Ngăn kho', q.info('unitCode')),
      ('Loại kho', q.info('unitType')),
      (
        'Ngày bắt đầu thuê',
        refundTime(q.details['startDate']).split(' · ').first
      ),
      ('Ngày hết hạn', refundTime(q.details['endDate']).split(' · ').first),
      ('Tổng tiền thuê', refundMoney(q.details['totalRentalFee'])),
      ('Phí dịch vụ', refundMoney(q.details['serviceFee'])),
    ];
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RentalAgreementScreen(
                fields: fields,
                agreement: RentalAgreement.fromJson(q.details))));
  }

  Widget _text(String value) => Text(value,
      style: const TextStyle(fontSize: 12, color: refundMuted, height: 1.5));
  Widget _bank(RefundViewData q) => RefundSection(
          icon: Icons.account_balance_outlined,
          title: 'Tài khoản nhận tiền',
          color: const Color(0xFFEDF3FC),
          children: [
            RefundInfoLine(
                Icons.account_balance_outlined,
                q.text('bankCode').isEmpty
                    ? 'Chưa có ngân hàng'
                    : q.text('bankCode'),
                strong: true),
            Row(children: [
              Expanded(
                  child: SelectableText(
                      q.text('bankAccountNumber').isEmpty
                          ? 'Chưa có số tài khoản'
                          : q.text('bankAccountNumber'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: refundInk))),
              if (q.text('bankAccountNumber').isNotEmpty)
                IconButton(
                    tooltip: 'Sao chép số tài khoản',
                    onPressed: () => _copy(q.text('bankAccountNumber')),
                    icon: const Icon(Icons.copy_outlined,
                        size: 19, color: refundBlue))
            ]),
            RefundInfoLine(
                Icons.person_outline,
                q.text('bankAccountName').isEmpty
                    ? 'Chưa có tên chủ tài khoản'
                    : q.text('bankAccountName')),
            _text(
                'Thông tin do khách hàng cung cấp cho yêu cầu hoàn tiền này.'),
          ]);
  Widget _breakdown(RefundViewData q) {
    final d = q.details;
    if (d.isEmpty) {
      return const RefundSection(
          icon: Icons.receipt_long_outlined,
          title: 'Chi tiết đối soát',
          children: [Text('Chưa có dữ liệu đối soát chi tiết từ máy chủ.')]);
    }
    final combined = d['rentalServiceSplitKnown'] != true;
    return RefundSection(
        icon: Icons.receipt_long_outlined,
        title: 'Chi tiết đối soát',
        children: [
          if (q.info('refundKind') != 'EXTRA_CHARGE') ...[
            RefundAmountRow('Cọc trước khấu trừ', d['depositBefore']),
            RefundAmountRow('Trừ phí trễ vào cọc', d['lateFeeDeduction']),
            RefundAmountRow('Trừ hư hại / vi phạm', d['damageDeduction']),
            if (q.info('refundKind') == 'CANCELLATION')
              RefundAmountRow('Cọc giữ lại theo chính sách hủy',
                  d['cancellationDeduction']),
            const Divider(height: 18),
            RefundAmountRow('Tiền cọc hoàn', d['depositRefund']),
            RefundAmountRow(
                combined ? 'Tiền thuê & phí dịch vụ hoàn' : 'Tiền thuê hoàn',
                d['rentalRefund']),
            if (!combined)
              RefundAmountRow('Phí dịch vụ hoàn', d['serviceFeeRefund']),
            if (combined)
              _text(
                  'Giao dịch cũ chưa lưu đủ dữ liệu để tách riêng tiền thuê và phí dịch vụ.'),
          ] else
            RefundAmountRow('Phí phát sinh hoàn', d['extraFeeRefund']),
          const Divider(height: 22),
          RefundAmountRow('Tổng hoàn tiền', q.raw['amount'], strong: true),
          _text(
              'Các khoản hoàn bên trên đã trừ khấu trừ. Tổng là số tiền thực tế cần chuyển cho khách.'),
          if (q.cancellationTiming.isNotEmpty) _text(q.cancellationTiming),
          if (q.info('refundKind') == 'CANCELLATION' &&
              d['depositRefundPercent'] != null) ...[
            const SizedBox(height: 10),
            _text(
                'Tỷ lệ cọc được hoàn theo đối soát: ${q.info('depositRefundPercent').replaceFirst(RegExp(r'\.0$'), '')}%.'),
          ],
        ]);
  }

  Widget _footer(RefundViewData q) {
    final confirm = q.canConfirm && q.hasBank;
    return SafeArea(
        top: false,
        child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE1E7EF)))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      q.completed
                          ? 'Yêu cầu đã hoàn tất.'
                          : q.canConfirm && !q.hasBank
                              ? 'Cần có đầy đủ tài khoản nhận tiền trước khi xác nhận.'
                              : q.canConfirm
                                  ? 'Kiểm tra số tiền và tài khoản trước khi xác nhận.'
                                  : 'Yêu cầu đang được xử lý theo trạng thái giao dịch.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: refundMuted)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                      onPressed: _enabled && confirm ? _confirmTransfer : null,
                      style: FilledButton.styleFrom(
                          backgroundColor: refundInk,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              q.completed
                                  ? Icons.check_circle_outline
                                  : Icons.account_balance_outlined,
                              size: 19),
                      label: Text(
                          q.completed
                              ? 'Đã hoàn tiền'
                              : 'Xác nhận đã chuyển khoản',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600))),
                ])));
  }

  @override
  Widget build(BuildContext context) {
    final q = _refund;
    final d = q.details;
    return Scaffold(
        backgroundColor: refundBackground,
        appBar: AppBar(
            title: const Text('Chi tiết hoàn tiền',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            backgroundColor: Colors.white,
            foregroundColor: refundInk,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                  tooltip: 'Tải lại chi tiết',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
        bottomNavigationBar: _footer(q),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Không tải được trạng thái mới nhất: $_error',
                              style: const TextStyle(
                                  color: Color(0xFFB45309), fontSize: 12)),
                          TextButton(
                              onPressed: _busy ? null : _load,
                              child: const Text('Thử lại'))
                        ])),
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SelectableText(q.text('bookingCode'),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: refundInk)),
                    RefundStatusBadge(q.status)
                  ]),
              const SizedBox(height: 10),
              _text(q.completed
                  ? 'Tổng đã chuyển cho khách'
                  : 'Tổng cần chuyển cho khách'),
              const SizedBox(height: 4),
              Text(refundMoney(q.raw['amount']),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: refundInk)),
              const SizedBox(height: 8),
              RefundInfoLine(Icons.schedule_outlined,
                  'Hạn hoàn: ${refundTime(q.raw['dueAt'])}'),
              if (q.overdueText.isNotEmpty)
                Text(q.overdueText,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309))),
              const SizedBox(height: 16),
              RefundSection(
                  icon: Icons.person_outline,
                  title: 'Khách hàng & đơn thuê',
                  children: [
                    RefundInfoLine(
                        Icons.person_outline,
                        q.info('customerName').isEmpty
                            ? 'Chưa có tên khách hàng'
                            : q.info('customerName'),
                        strong: true),
                    RefundInfoLine(
                        Icons.phone_outlined,
                        q.info('customerPhone').isEmpty
                            ? 'Chưa có số điện thoại'
                            : q.info('customerPhone')),
                    RefundInfoLine(
                        Icons.mail_outline,
                        q.info('customerEmail').isEmpty
                            ? 'Chưa có email'
                            : q.info('customerEmail')),
                    RefundInfoLine(
                        Icons.location_on_outlined,
                        q.facilityUnit.isEmpty
                            ? 'Chưa có thông tin cơ sở'
                            : q.facilityUnit),
                    RefundInfoLine(Icons.sell_outlined, q.kind),
                    if (q.info('reason').isNotEmpty) _text(q.info('reason')),
                  ]),
              _breakdown(q),
              RefundSection(
                  icon: Icons.event_outlined,
                  title: 'Mốc thời gian & chính sách',
                  children: [
                    RefundInfoLine(Icons.event_outlined,
                        'Đặt kho: ${refundTime(d['bookedAt'])}'),
                    RefundInfoLine(Icons.history,
                        'Yêu cầu hoàn: ${refundTime(d['requestedAt'])}'),
                    if (q.info('refundKind') == 'RETURN') ...[
                      RefundInfoLine(Icons.event_busy_outlined,
                          'Hạn thuê: ${refundTime(d['endDate']).split(' · ').first}'),
                      RefundInfoLine(Icons.assignment_return_outlined,
                          'Nhận lại kho: ${refundTime(d['returnedAt'])}'),
                      _text(
                          'Trễ ${d['overdueDays'] ?? 0} ngày. Ân hạn: ${(d['rentalPolicy'] as Map?)?['overdueGraceDays'] ?? 'theo hợp đồng'} ngày. Phí trễ mỗi ngày: ${refundMoney((d['rentalPolicy'] as Map?)?['dailyLateFee'])}.'),
                    ],
                    if (q.text('originalTransactionId').isNotEmpty)
                      RefundInfoLine(Icons.receipt_outlined,
                          'Giao dịch gốc: ${q.text('originalTransactionId')}'),
                  ]),
              _bank(q),
              if (q.completed)
                RefundSection(
                    icon: Icons.task_alt,
                    title: 'Thông tin hoàn tất',
                    children: [
                      RefundInfoLine(Icons.schedule_outlined,
                          'Đã chuyển: ${refundTime(d['completedAt'])}'),
                      RefundInfoLine(Icons.person_outline,
                          'Người xác nhận: ${q.info('confirmedByName').isEmpty ? 'Chưa ghi nhận' : q.info('confirmedByName')}'),
                      RefundInfoLine(Icons.receipt_long_outlined,
                          'Mã giao dịch: ${q.text('transferReference').isEmpty ? 'Chưa ghi nhận' : q.text('transferReference')}'),
                      if (q.info('transferNotes').isNotEmpty)
                        _text('Ghi chú: ${q.info('transferNotes')}'),
                    ]),
              if (!q.completed &&
                  const {
                    'MISSING_METADATA',
                    'REJECTED',
                    'NEEDS_REVIEW',
                    'SENDING',
                    'AWAITING_CONFIRMATION'
                  }.contains(q.status))
                RefundSection(
                    icon: Icons.sync,
                    title: 'Đối soát giao dịch',
                    children: [
                      if (q.text('gatewayResponseCode').isNotEmpty)
                        _text(
                            'Mã phản hồi VNPay: ${q.text('gatewayResponseCode')}'),
                      if (const {'MISSING_METADATA', 'REJECTED'}
                          .contains(q.status))
                        OutlinedButton(
                            onPressed: _enabled ? _metadata : null,
                            child: const Text('Bổ sung giao dịch gốc')),
                      if (q.status == 'REJECTED')
                        OutlinedButton(
                            onPressed: _enabled
                                ? () => _run(
                                    () => widget.service.retryRejectedRefund(
                                        widget.facilityId, q.text('id')),
                                    'Đã gửi lại yêu cầu VNPay.')
                                : null,
                            child: const Text('Gửi lại VNPay')),
                      if (const {
                        'NEEDS_REVIEW',
                        'SENDING',
                        'AWAITING_CONFIRMATION'
                      }.contains(q.status))
                        OutlinedButton(
                            onPressed: _enabled
                                ? () => _run(
                                    () => widget.service.reconcileRefund(
                                        widget.facilityId, q.text('id')),
                                    'Đã đối soát với VNPay.')
                                : null,
                            child: const Text('Đối soát VNPay')),
                    ]),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: refundInk,
                      minimumSize: const Size(0, 46),
                      side: const BorderSide(color: Color(0xFFBAC7D8))),
                  onPressed: d.isEmpty ? null : _contract,
                  icon: const Icon(Icons.description_outlined, size: 19),
                  label: const Text('Xem hợp đồng')),
              const SizedBox(height: 10),
            ])));
  }
}
