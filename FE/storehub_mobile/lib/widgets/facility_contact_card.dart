import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FacilityContactCard extends StatelessWidget {
  final String managerName, phone, email;
  const FacilityContactCard(
      {super.key, this.managerName = '', this.phone = '', this.email = ''});

  Future<void> _contact(
      BuildContext context, String scheme, String value) async {
    try {
      if (await launchUrl(Uri(scheme: scheme, path: value))) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép thông tin liên hệ.')));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F6FA),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.support_agent, size: 18),
          SizedBox(width: 6),
          Expanded(
              child: Text('Liên hệ cơ sở',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))
        ]),
        const SizedBox(height: 6),
        Text(
            managerName.trim().isEmpty
                ? 'Quản lý: Cơ sở chưa cập nhật'
                : 'Quản lý: $managerName',
            style: const TextStyle(fontSize: 12)),
        if (phone.trim().isNotEmpty)
          _row(context, Icons.phone_outlined, 'tel', phone),
        if (email.trim().isNotEmpty)
          _row(context, Icons.mail_outline, 'mailto', email),
        if (phone.trim().isEmpty && email.trim().isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Cơ sở chưa cập nhật số điện thoại hoặc email liên hệ.',
                  style: TextStyle(fontSize: 11, color: Colors.grey))),
      ]));

  Widget _row(
          BuildContext context, IconData icon, String scheme, String value) =>
      InkWell(
          onTap: () => _contact(context, scheme, value),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1D4ED8)))),
                const Icon(Icons.open_in_new,
                    size: 14, color: Color(0xFF1D4ED8)),
              ])));
}
