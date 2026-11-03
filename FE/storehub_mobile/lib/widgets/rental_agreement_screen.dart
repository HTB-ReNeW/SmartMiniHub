import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rental_agreement.dart';

class RentalAgreementScreen extends StatelessWidget {
  final List<(String, String)> fields;
  final RentalAgreement agreement;
  const RentalAgreementScreen(
      {super.key, required this.fields, required this.agreement});
  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.tryParse(agreement.acceptedAt);
    return Scaffold(
        appBar: AppBar(title: const Text('Hợp đồng & Cam kết lưu kho')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          _section(
              'Hợp đồng thuê kho',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final field in fields)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(field.$1,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 3),
                            SelectableText(field.$2.isEmpty
                                ? 'Chưa có thông tin'
                                : field.$2),
                          ]))
              ])),
          _section(
              'Xác nhận của khách hàng',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(agreement.termsAccepted
                    ? 'Đã đồng ý điều khoản thuê kho'
                    : 'Chưa có dữ liệu xác nhận điều khoản'),
                const SizedBox(height: 8),
                Text(agreement.prohibitedItemsAccepted
                    ? 'Đã cam kết không lưu trữ hàng hóa thuộc danh mục cấm và chịu trách nhiệm nếu vi phạm.'
                    : 'Chưa có dữ liệu xác nhận cam kết hàng cấm'),
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Thời điểm xác nhận: ${DateFormat('dd/MM/yyyy HH:mm').format(timestamp)}')
                ],
                if (agreement.version.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Phiên bản điều khoản: ${agreement.version}')
                ],
              ])),
          _section(
              'Danh mục hàng hóa cấm lưu trữ',
              SelectableText(agreement.prohibitedItems.isEmpty
                  ? 'Đơn thuê này chưa lưu nội dung danh mục hàng cấm.'
                  : agreement.prohibitedItems)),
          _section(
              'Điều khoản hợp đồng thuê kho',
              SelectableText(agreement.terms.isEmpty
                  ? 'Đơn thuê này chưa lưu nội dung điều khoản.'
                  : agreement.terms)),
        ]));
  }

  Widget _section(String title, Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        child
      ]));
}
