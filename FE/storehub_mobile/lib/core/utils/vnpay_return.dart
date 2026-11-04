/// Route the signed return query through the API the app can actually reach.
/// Never change the payment URL itself: its return URL is part of the signature.
Uri? resolveVnpayReturn(
    String paymentUrl, String navigationUrl, String apiBaseUrl) {
  final payment = Uri.tryParse(paymentUrl);
  final configured =
      Uri.tryParse(payment?.queryParameters['vnp_ReturnUrl'] ?? '');
  final navigation = Uri.tryParse(navigationUrl);
  if (configured == null ||
      navigation == null ||
      !{'http', 'https'}.contains(configured.scheme) ||
      navigation.scheme != configured.scheme ||
      navigation.host != configured.host ||
      navigation.port != configured.port ||
      navigation.path != configured.path ||
      !navigation.queryParameters.containsKey('vnp_SecureHash')) {
    return null;
  }
  final api = Uri.parse(apiBaseUrl);
  return api.removeFragment().replace(
    path: '${api.path.replaceFirst(RegExp(r'/+$'), '')}/payments/vnpay-return',
    query: navigation.query,
  );
}
