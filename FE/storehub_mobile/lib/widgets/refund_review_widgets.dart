import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/utils/vi_labels.dart';

const refundInk = Color(0xFF14243D);
const refundMuted = Color(0xFF64748B);
const refundBlue = Color(0xFF1D4ED8);
const refundBackground = Color(0xFFF5F7FB);

class RefundViewData {
  final Map<String, dynamic> raw;
  RefundViewData(this.raw);
  Map<String, dynamic> get details =>
      Map<String, dynamic>.from(raw['details'] as Map? ?? {});
  String text(String key) => raw[key]?.toString().trim() ?? '';
  String info(String key) => details[key]?.toString().trim() ?? '';
  String get status => text('status');
  bool get completed => status == 'COMPLETED';
  bool get canConfirm => const {
        'AWAITING_BANK_TRANSFER',
        'AWAITING_CONFIRMATION',
        'NEEDS_REVIEW',
        'REJECTED'
      }.contains(status);
  bool get hasBank =>
      text('bankCode').isNotEmpty &&
      text('bankAccountNumber').isNotEmpty &&
      text('bankAccountName').isNotEmpty;
  String get kind => switch (info('refundKind')) {
        'CANCELLATION' => 'Hủy trước nhận kho',
        'RETURN' => 'Hoàn cọc sau trả kho',
        'EXTRA_CHARGE' => 'Hoàn phí phát sinh',
        _ => 'Hoàn tiền theo đối soát',
      };
  String get facilityUnit => [
        info('facilityName'),
        info('unitCode').isEmpty ? '' : 'Ngăn ${info('unitCode')}'
      ].where((s) => s.isNotEmpty).join(' · ');
  String get cancellationTiming {
    if (info('refundKind') != 'CANCELLATION') return '';
    final booked = refundDate(details['bookedAt']),
        requested = refundDate(details['requestedAt']);
    if (booked == null || requested == null || requested.isBefore(booked)) {
      return '';
    }
    return requested.difference(booked).compareTo(const Duration(hours: 24)) <=
            0
        ? 'Yêu cầu trong 24 giờ từ lúc đặt kho.'
        : 'Yêu cầu sau 24 giờ từ lúc đặt kho.';
  }

  String get overdueText {
    if (completed) return '';
    final due = refundDate(raw['dueAt']);
    if (due == null) {
      return raw['overdue'] == true ? 'Đã quá hạn hoàn tiền' : '';
    }
    final utc = DateTime.now().toUtc().add(const Duration(hours: 7));
    final now = DateTime(
        utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
    final late = now.difference(due);
    if (late.isNegative) return '';
    return late.inDays > 0
        ? 'Quá hạn ${late.inDays} ngày ${late.inHours % 24} giờ'
        : late.inHours > 0
            ? 'Quá hạn ${late.inHours} giờ'
            : 'Đã đến hạn hoàn tiền';
  }
}

DateTime? refundDate(dynamic raw) {
  if (raw == null) return null;
  final value = DateTime.tryParse(raw.toString());
  if (value == null) return null;
  if (RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw.toString())) {
    final vn = value.toUtc().add(const Duration(hours: 7));
    return DateTime(vn.year, vn.month, vn.day, vn.hour, vn.minute, vn.second);
  }
  return value;
}

String refundTime(dynamic raw) {
  final date = refundDate(raw);
  return date == null
      ? 'Chưa ghi nhận'
      : DateFormat('dd/MM/yyyy · HH:mm').format(date);
}

String refundMoney(dynamic raw) {
  final value = raw is num ? raw : num.tryParse('$raw');
  return value == null
      ? 'Chưa ghi nhận'
      : NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0)
          .format(value);
}

class RefundStatusBadge extends StatelessWidget {
  final String status;
  const RefundStatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final done = status == 'COMPLETED';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: done ? const Color(0xFFE8F7EE) : const Color(0xFFFFF2D9),
            borderRadius: BorderRadius.circular(8)),
        child: Text(
            done
                ? 'Đã hoàn tiền'
                : status == 'AWAITING_BANK_TRANSFER'
                    ? 'Chờ chuyển khoản'
                    : ViLabels.refund(status),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    done ? const Color(0xFF22714C) : const Color(0xFF915F15))));
  }
}

class RefundInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;
  final Color? color;
  const RefundInfoLine(this.icon, this.text,
      {super.key, this.strong = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: color ?? refundMuted),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: strong ? FontWeight.w600 : FontWeight.normal,
                    color: color ?? refundInk))),
      ]));
}

class RefundSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color color;
  const RefundSection(
      {super.key,
      required this.icon,
      required this.title,
      required this.children,
      this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0xFFE1E7EF)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: refundInk),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: refundInk)))
        ]),
        const SizedBox(height: 12),
        ...children,
      ]));
}

class RefundAmountRow extends StatelessWidget {
  final String label;
  final dynamic amount;
  final bool strong;
  const RefundAmountRow(this.label, this.amount,
      {super.key, this.strong = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: refundInk,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.normal))),
        const SizedBox(width: 10),
        Expanded(
            flex: 2,
            child: Text(refundMoney(amount),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: strong ? 15 : 13,
                    color: refundInk,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
      ]));
}
