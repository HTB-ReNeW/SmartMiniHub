import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/utils/vnpay_return.dart';

void main() {
  const returnUrl = 'http://10.0.2.2:8080/api/v1/payments/vnpay-return';
  final paymentUrl = Uri.https('sandbox.vnpayment.vn', '/paymentv2/vpcpay.html',
      {'vnp_ReturnUrl': returnUrl}).toString();
  const query =
      'vnp_TxnRef=TXN-123&vnp_OrderInfo=Thanh+toan%20kho&vnp_SecureHash=abc';

  test('physical device forwards the original signed query to its API', () {
    final result = resolveVnpayReturn(
        paymentUrl, '$returnUrl?$query', 'http://192.168.1.5:8080/api/v1/');
    expect(result.toString(),
        'http://192.168.1.5:8080/api/v1/payments/vnpay-return?$query');
    expect(result!.query, query);
  });

  test('does not intercept payment pages or unsigned/unrelated redirects', () {
    for (final url in [
      paymentUrl,
      returnUrl,
      'http://evil.example/api/v1/payments/vnpay-return?$query',
      'http://10.0.2.2:8080/other?$query'
    ]) {
      expect(resolveVnpayReturn(paymentUrl, url, 'https://api.example/api/v1'),
          isNull);
    }
  });
}
