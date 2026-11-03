class RentalAgreement {
  final List<String> contractPhotos;
  final String terms, prohibitedItems, version, acceptedAt;
  final bool termsAccepted, prohibitedItemsAccepted;
  const RentalAgreement(
      {this.contractPhotos = const [],
      this.terms = '',
      this.prohibitedItems = '',
      this.version = '',
      this.acceptedAt = '',
      this.termsAccepted = false,
      this.prohibitedItemsAccepted = false});
  factory RentalAgreement.fromJson(Map<String, dynamic> json) =>
      RentalAgreement(
          contractPhotos: (json['contractPhotos'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
          terms: json['termsContentSnapshot']?.toString() ?? '',
          prohibitedItems: json['prohibitedItemsSnapshot']?.toString() ?? '',
          version: json['termsVersion']?.toString() ?? '',
          acceptedAt: json['termsAcceptedAt']?.toString() ?? '',
          termsAccepted: json['termsAccepted'] == true,
          prohibitedItemsAccepted: json['prohibitedItemsAccepted'] == true);
}
