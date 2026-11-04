import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rental_agreement.dart';

class RentalPolicyTerms extends StatelessWidget {
  final RentalPolicy policy;
  final DateTime? endDate;
  const RentalPolicyTerms({super.key, required this.policy, this.endDate});

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final grace = policy.graceDays;
    final firstCharge = endDate == null || grace == null
        ? null
        : endDate!.add(Duration(days: grace + 1));
    final lines = <String>[
      if (policy.legacy)
        'Đơn cũ: một số thông tin chính sách được bổ sung từ hồ sơ hiện có.',
      if (grace != null)
        'Ân hạn: $grace ngày sau ngày hết hạn; miễn phí trễ hạn trong thời gian ân hạn.',
      if (policy.dailyLateFee != null)
        'Phí trễ hạn: ${currency.format(policy.dailyLateFee)}/ngày'
            '${grace == null ? '.' : ', từ ngày quá hạn thứ ${grace + 1}'}'
            '${firstCharge == null ? (grace == null ? '' : '.') : ' (${DateFormat('dd/MM/yyyy').format(firstCharge)}).'}'
            ' Số tiền = số ngày vượt ân hạn × phí mỗi ngày, tính đến ngày nhân viên xác nhận nhận lại kho.',
      if (policy.disableDays != null)
        policy.disableDays == 0
            ? 'Khóa mã truy cập/PIN khi bắt đầu quá hạn.'
            : 'Khóa mã truy cập/PIN từ ngày quá hạn thứ ${policy.disableDays}.',
      if (policy.sealingDays != null)
        policy.sealingDays == 0
            ? 'Khi bắt đầu quá hạn: chuyển chờ quản lý duyệt niêm phong.'
            : 'Từ ngày quá hạn thứ ${policy.sealingDays}: chuyển chờ quản lý duyệt niêm phong; không tự động duyệt.',
      'Đặt lịch chưa được tính là đã trả kho. Đổi lịch không gia hạn hợp đồng, không dừng tính phí và không dời mốc khóa PIN/niêm phong. Khách vẫn có thể yêu cầu trả kho và phối hợp với cơ sở, nhân viên để bàn giao.',
      if (policy.refundSlaDays != null) ...[
        'Trả kho: hoàn cọc trong tối đa ${policy.refundSlaDays} ngày kể từ khi nhân viên xác nhận hoàn tất nhận lại kho, sau đối soát công nợ và khấu trừ theo hợp đồng.',
        'Hủy trước khi nhận kho: hoàn tiền trong tối đa ${policy.refundSlaDays} ngày kể từ khi hệ thống ghi nhận yêu cầu hủy hợp lệ và đầy đủ thông tin tài khoản nhận tiền.',
        'Đây là thời hạn xử lý hoàn tiền. Mốc trong/sau 24 giờ kể từ lúc đặt quyết định tỷ lệ hoàn cọc, không phải thời hạn chuyển tiền.',
      ] else
        'Đơn này chưa có dữ liệu thời hạn xử lý hoàn tiền.',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final line in lines)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Text(line, style: const TextStyle(fontSize: 13, height: 1.6))),
    ]);
  }
}
