class RentalAgreement {
  final RentalPolicy policy;
  final DateTime? endDate;
  final List<String> contractPhotos;
  final String terms, prohibitedItems, version, acceptedAt;
  final bool termsAccepted, prohibitedItemsAccepted;
  const RentalAgreement(
      {this.endDate,
      this.policy = const RentalPolicy(),
      this.contractPhotos = const [],
      this.terms = '',
      this.prohibitedItems = '',
      this.version = '',
      this.acceptedAt = '',
      this.termsAccepted = false,
      this.prohibitedItemsAccepted = false});
  factory RentalAgreement.fromJson(Map<String, dynamic> json) =>
      RentalAgreement(
          endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
          policy: RentalPolicy.fromJson(
              Map<String, dynamic>.from(json['rentalPolicy'] as Map? ?? {})),
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

class RentalPolicy {
  final double? dailyLateFee;
  final int? graceDays, disableDays, sealingDays, refundSlaDays;
  final int returnNoticeDays;
  final bool legacy;
  const RentalPolicy(
      {this.dailyLateFee,
      this.graceDays,
      this.disableDays,
      this.sealingDays,
      this.refundSlaDays,
      this.returnNoticeDays = 0,
      this.legacy = false});
  factory RentalPolicy.fromJson(Map<String, dynamic> json) => RentalPolicy(
        dailyLateFee: (json['dailyLateFee'] as num?)?.toDouble(),
        graceDays: (json['overdueGraceDays'] as num?)?.toInt(),
        disableDays: (json['overdueAccessDisableDays'] as num?)?.toInt(),
        sealingDays: (json['overdueSealingDays'] as num?)?.toInt(),
        refundSlaDays: (json['refundSlaDays'] as num? ??
                json['depositRefundSlaDays'] as num?)
            ?.toInt(),
        returnNoticeDays: (json['returnNoticeDays'] as num?)?.toInt() ?? 0,
        legacy: json['legacy'] == true,
      );
}
