import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/return_settlement.dart';

class ReturnSettlementCard extends StatelessWidget {
  final ReturnSettlement? settlement;
  const ReturnSettlementCard({super.key, required this.settlement});
  @override
  Widget build(BuildContext context) {
    final q = settlement;
    final money =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final date = DateFormat('dd/MM/yyyy');
    Widget row(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 3,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(
              flex: 2,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: strong ? FontWeight.bold : FontWeight.w500))),
        ]));
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              q?.finalized == true
                  ? 'Đối soát trả kho'
                  : 'Dự tính hoàn cọc nếu trả hôm nay',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (q == null)
            const Text(
                'Chưa tải được đối soát. Vui lòng tải lại Kho của tôi để xem số tiền chính xác.',
                style: TextStyle(fontSize: 12))
          else ...[
            row('Hạn trả theo hợp đồng',
                q.endDate == null ? 'Chưa có' : date.format(q.endDate!)),
            row(q.finalized ? 'Ngày đã bàn giao trả kho' : 'Nếu trả hôm nay',
                q.returnAt == null ? 'Chưa có' : date.format(q.returnAt!)),
            row('Số ngày trễ', '${q.overdueDays} ngày', strong: true),
            row('Thời gian ân hạn',
                q.graceDays == null ? 'Theo hợp đồng' : '${q.graceDays} ngày'),
            row('Số ngày tính phí', '${q.chargeableDays} ngày'),
            row(
                'Phí trễ mỗi ngày',
                q.dailyLateFee == null
                    ? 'Theo hợp đồng'
                    : money.format(q.dailyLateFee)),
            row('Tổng phí trễ hạn', money.format(q.totalLateFee)),
            if (q.lateFeeAlreadyPaid > 0)
              row('Phí trễ đã thanh toán riêng',
                  money.format(q.lateFeeAlreadyPaid)),
            const Divider(),
            row('Tiền cọc trước đối soát', money.format(q.depositBefore)),
            row('Trừ phí trễ vào cọc', '- ${money.format(q.lateFeeDeduction)}'),
            row('Trừ hư hại / vi phạm', '- ${money.format(q.damageDeduction)}'),
            const Divider(),
            row(
                q.finalized
                    ? 'Tiền cọc được hoàn'
                    : 'Tiền cọc dự kiến nhận lại',
                money.format(q.depositRefund),
                strong: true),
            row('Phần phải trả thêm', money.format(q.additionalPayment),
                strong: true),
            const SizedBox(height: 8),
            Text(
                q.finalized
                    ? 'Kho đã được nhận lại. Không phát sinh thêm phí trễ sau thời điểm bàn giao. Tiền cọc được xử lý hoàn theo thời hạn hợp đồng.'
                    : 'Phí trễ được trừ vào cọc; chỉ thanh toán thêm nếu cọc không đủ. Ngày hẹn khác hôm nay sẽ có số ngày trễ khác. Nhân viên chốt tiền theo ngày nhận lại kho và hư hại thực tế.',
                style: const TextStyle(fontSize: 11, height: 1.5)),
          ],
        ]));
  }
}
