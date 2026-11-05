class ReturnSettlement {
  final DateTime? endDate, returnAt;
  final int overdueDays, chargeableDays;
  final int? graceDays;
  final double? dailyLateFee;
  final double totalLateFee,
      lateFeeAlreadyPaid,
      depositBefore,
      lateFeeDeduction,
      damageDeduction,
      depositRefund,
      additionalPayment;
  final bool finalized;
  ReturnSettlement.fromJson(Map<String, dynamic> json)
      : endDate = DateTime.tryParse('${json['endDate'] ?? ''}'),
        returnAt = DateTime.tryParse('${json['returnAt'] ?? ''}'),
        overdueDays = (json['overdueDays'] as num?)?.toInt() ?? 0,
        chargeableDays = (json['chargeableDays'] as num?)?.toInt() ?? 0,
        graceDays = (json['graceDays'] as num?)?.toInt(),
        dailyLateFee = (json['dailyLateFee'] as num?)?.toDouble(),
        totalLateFee = (json['totalLateFee'] as num?)?.toDouble() ?? 0,
        lateFeeAlreadyPaid =
            (json['lateFeeAlreadyPaid'] as num?)?.toDouble() ?? 0,
        depositBefore = (json['depositBefore'] as num?)?.toDouble() ?? 0,
        lateFeeDeduction = (json['lateFeeDeduction'] as num?)?.toDouble() ?? 0,
        damageDeduction = (json['damageDeduction'] as num?)?.toDouble() ?? 0,
        depositRefund = (json['depositRefund'] as num?)?.toDouble() ?? 0,
        additionalPayment =
            (json['additionalPayment'] as num?)?.toDouble() ?? 0,
        finalized = json['finalized'] == true;
}
