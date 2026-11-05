import 'photo_preview_dialog.dart';
import 'rental_policy_terms.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rental_agreement.dart';

class RentalAgreementScreen extends StatelessWidget {
  final List<(String, String)> fields;
  final RentalAgreement agreement;
  const RentalAgreementScreen(
      {super.key, required this.fields, required this.agreement});

  static const _ink = Color(0xFF172333);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.tryParse(agreement.acceptedAt);
    final codes = fields.where((f) => f.$1 == 'Mã đơn thuê');
    final details = fields.where((f) => f.$1 != 'Mã đơn thuê').toList();
    final accepted =
        agreement.termsAccepted && agreement.prohibitedItemsAccepted;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: const Text('Hợp đồng thuê kho',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SelectionArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 16,
                        offset: Offset(0, 4))
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 4, color: _ink),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(children: [
                                Icon(Icons.warehouse_outlined,
                                    size: 22, color: _ink),
                                SizedBox(width: 8),
                                Text('STOREHUB',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 2,
                                        color: _ink))
                              ]),
                              const SizedBox(height: 24),
                              const Text('HỢP ĐỒNG THUÊ KHO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                      color: _ink)),
                              const SizedBox(height: 4),
                              const Text('VÀ CAM KẾT LƯU TRỮ HÀNG HÓA',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.8,
                                      height: 1.6,
                                      color: _muted)),
                              if (codes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(codes.first.$2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12, color: _muted)),
                              ],
                              const SizedBox(height: 24),
                              const Divider(height: 1, color: _line),
                              _heading('01', 'Thông tin thuê kho'),
                              for (final field in details)
                                _field(field.$1, field.$2),
                              _heading('02', 'Điều khoản thuê kho'),
                              _paragraphs(agreement.terms,
                                  'Đơn thuê này chưa lưu nội dung điều khoản.'),
                              const SizedBox(height: 12),
                              const Text(
                                  'Chính sách quá hạn & thời hạn hoàn tiền',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              RentalPolicyTerms(
                                  policy: agreement.policy,
                                  endDate: agreement.endDate),
                              _heading('03', 'Danh mục hàng hóa cấm lưu trữ'),
                              _paragraphs(agreement.prohibitedItems,
                                  'Đơn thuê này chưa lưu nội dung danh mục hàng cấm.',
                                  bullets: true),
                              if (agreement.contractPhotos.isNotEmpty) ...[
                                _heading('04', 'Ảnh hợp đồng đã ký'),
                                PhotoThumbnailGrid(
                                    photos: agreement.contractPhotos, size: 80),
                              ],
                              _heading(
                                  agreement.contractPhotos.isEmpty
                                      ? '04'
                                      : '05',
                                  'Xác nhận & cam kết của khách hàng'),
                              _confirmation(
                                  agreement.termsAccepted,
                                  'Đã đồng ý điều khoản thuê kho',
                                  'Chưa có dữ liệu xác nhận điều khoản'),
                              const SizedBox(height: 12),
                              _confirmation(
                                  agreement.prohibitedItemsAccepted,
                                  'Đã cam kết không lưu trữ hàng hóa thuộc danh mục cấm và chịu trách nhiệm nếu vi phạm.',
                                  'Chưa có dữ liệu xác nhận cam kết hàng cấm'),
                              const SizedBox(height: 20),
                              Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      border: Border.all(color: _line),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Icon(
                                              accepted
                                                  ? Icons.verified_outlined
                                                  : Icons.info_outline,
                                              size: 18,
                                              color: _muted),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  accepted
                                                      ? 'Đã xác nhận trên hệ thống'
                                                      : 'Thông tin xác nhận',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _ink)))
                                        ]),
                                        if (timestamp != null) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                              'Thời điểm xác nhận: ${DateFormat('dd/MM/yyyy · HH:mm').format(timestamp)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.5,
                                                  color: _muted))
                                        ],
                                        if (agreement.version.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                              'Phiên bản điều khoản: ${agreement.version}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.5,
                                                  color: _muted))
                                        ],
                                      ])),
                              const SizedBox(height: 24),
                              const Divider(height: 1, color: _line),
                              const SizedBox(height: 14),
                              const Text(
                                  'STOREHUB  /  HỢP ĐỒNG & CAM KẾT LƯU KHO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 0.6,
                                      height: 1.6,
                                      color: _muted)),
                            ])),
                  ]),
            ),
          ))
        ],
      )),
    );
  }

  Widget _heading(String number, String title) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(number,
              style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: _muted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _ink))),
        ]),
      );

  Widget _field(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _line))),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelWidget = Text(label,
              style: const TextStyle(fontSize: 12, height: 1.6, color: _muted));
          final valueWidget = Text(value.isEmpty ? 'Chưa có thông tin' : value,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: _ink,
                  fontWeight: FontWeight.w500));
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelWidget,
                  const SizedBox(height: 3),
                  valueWidget
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: constraints.maxWidth * 0.4, child: labelWidget),
            const SizedBox(width: 12),
            Expanded(child: valueWidget),
          ]);
        }),
      );

  Widget _paragraphs(String content, String fallback, {bool bullets = false}) {
    final items = content.trim().isEmpty
        ? [fallback]
        : content
            .split(bullets ? RegExp(r'[;\n]+') : RegExp(r'\n+'))
            .map((text) => text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final item in items)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (bullets && content.trim().isNotEmpty)
                const Padding(
                    padding: EdgeInsets.only(right: 10, top: 2),
                    child: Text('•', style: TextStyle(color: _muted))),
              Expanded(
                  child: Text(item,
                      style: const TextStyle(
                          fontSize: 13, height: 1.8, color: _ink))),
            ])),
    ]);
  }

  Widget _confirmation(bool confirmed, String yes, String missing) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(confirmed ? Icons.check_circle_outline : Icons.info_outline,
              size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
              child: Text(confirmed ? yes : missing,
                  style:
                      const TextStyle(fontSize: 13, height: 1.7, color: _ink))),
        ],
      );
}
