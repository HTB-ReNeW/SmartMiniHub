import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RefundAccountDialog extends StatefulWidget {
  final Future<void> Function(Map<String, String>) onSubmit;
  const RefundAccountDialog({super.key, required this.onSubmit});
  @override
  State<RefundAccountDialog> createState() => _RefundAccountDialogState();
}

class _RefundAccountDialogState extends State<RefundAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'bankCode': _bank.text.trim(),
        'bankAccountNumber': _number.text.trim(),
        'bankAccountName': _name.text.trim()
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: const Text('Tài khoản nhận hoàn tiền'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'Nhập chính xác tài khoản để cơ sở chuyển khoản hoàn tiền. Đơn chỉ được hủy khi bạn gửi thông tin bên dưới.',
                          style: TextStyle(fontSize: 13, height: 1.5)),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _bank,
                          enabled: !_submitting,
                          maxLength: 100,
                          decoration: const InputDecoration(
                              labelText: 'Ngân hàng',
                              hintText: 'Ví dụ: Vietcombank',
                              counterText: ''),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Vui lòng nhập ngân hàng'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _number,
                          enabled: !_submitting,
                          maxLength: 34,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Số tài khoản', counterText: ''),
                          validator: (v) => v == null ||
                                  !RegExp(r'^[0-9]{4,34}$').hasMatch(v.trim())
                              ? 'Nhập số tài khoản từ 4 đến 34 chữ số'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _name,
                          enabled: !_submitting,
                          maxLength: 100,
                          decoration: const InputDecoration(
                              labelText: 'Tên chủ tài khoản', counterText: ''),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Vui lòng nhập tên chủ tài khoản'
                              : null),
                      const SizedBox(height: 12),
                      const Text(
                          'Vui lòng kiểm tra ngân hàng, số tài khoản và tên chủ tài khoản trước khi gửi.',
                          style: TextStyle(fontSize: 12)),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))
                      ],
                    ]))),
        actions: [
          TextButton(
              onPressed:
                  _submitting ? null : () => Navigator.pop(context, false),
              child: const Text('Quay lại')),
          FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                  _submitting ? 'Đang gửi...' : 'Gửi yêu cầu hủy & hoàn tiền'))
        ],
      ));
}
