class RentalAgreement {
  final String terms, prohibitedItems, version, acceptedAt;
  final bool termsAccepted, prohibitedItemsAccepted;
  const RentalAgreement(
      {this.terms = '',
      this.prohibitedItems = '',
      this.version = '',
      this.acceptedAt = '',
      this.termsAccepted = false,
      this.prohibitedItemsAccepted = false});
  factory RentalAgreement.fromJson(Map<String, dynamic> json) =>
      RentalAgreement(
          terms: json['termsContentSnapshot']?.toString() ?? '',
          prohibitedItems: json['prohibitedItemsSnapshot']?.toString() ?? '',
          version: json['termsVersion']?.toString() ?? '',
          acceptedAt: json['termsAcceptedAt']?.toString() ?? '',
          termsAccepted: json['termsAccepted'] == true,
          prohibitedItemsAccepted: json['prohibitedItemsAccepted'] == true);
}
