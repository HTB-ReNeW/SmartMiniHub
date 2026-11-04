import 'rental_agreement.dart';

class MyUnitModel {
  final String refundBankCode,
      refundAccountNumber,
      refundAccountName,
      checkoutNotes;
  final bool refundCompleted;
  final RentalAgreement agreement;
  final String customerName;
  final double? serviceFee;
  final String bookingId;
  final String handoverIssueStatus;
  final String handoverIssueReason;
  final String handoverIssueDueAt;
  final String bookingCode;
  final String unitCode;
  final bool unitAssignmentConfirmed;
  final String facilityName;
  final String facilityAddress;
  final String facilityManagerName, facilityContactPhone, facilityContactEmail;
  final String typeName;
  final String status;
  final double totalRentalFee;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasActiveAccess;
  final String dimensions;
  final double? areaSqm;
  final int? rentalMonths;
  final double? depositPaid;
  final bool hasPendingExtension;
  final int? pendingExtraMonths;
  final DateTime? pendingNewEndDate;
  final double? pendingExtensionFee;
  final DateTime? renewalOpensDate;
  final bool _reportedOverdue;
  final int _reportedOverdueDays;
  final double overdueFeeOutstanding;
  final bool accessDisabled;
  final DateTime? scheduledReturnTime;
  final String? openTime;
  final String? closeTime;

  MyUnitModel({
    this.refundBankCode = '',
    this.refundAccountNumber = '',
    this.refundAccountName = '',
    this.checkoutNotes = '',
    this.refundCompleted = false,
    this.agreement = const RentalAgreement(),
    this.customerName = '',
    this.serviceFee,
    required this.bookingId,
    this.handoverIssueStatus = '',
    this.handoverIssueReason = '',
    this.handoverIssueDueAt = '',
    required this.bookingCode,
    required this.unitCode,
    this.unitAssignmentConfirmed = false,
    required this.facilityName,
    required this.facilityAddress,
    this.facilityManagerName = '',
    this.facilityContactPhone = '',
    this.facilityContactEmail = '',
    required this.typeName,
    required this.status,
    required this.totalRentalFee,
    this.startDate,
    this.endDate,
    this.hasActiveAccess = false,
    this.dimensions = '',
    this.areaSqm,
    this.rentalMonths,
    this.depositPaid,
    this.hasPendingExtension = false,
    this.pendingExtraMonths,
    this.pendingNewEndDate,
    this.pendingExtensionFee,
    this.renewalOpensDate,
    bool overdue = false,
    int overdueDays = 0,
    this.overdueFeeOutstanding = 0,
    this.accessDisabled = false,
    this.scheduledReturnTime,
    this.openTime,
    this.closeTime,
  })  : _reportedOverdue = overdue,
        _reportedOverdueDays = overdueDays;

  /// Rental dates follow Vietnam calendar days, independently of the device timezone.
  int overdueDaysAt(DateTime instant) {
    if (!isActive) return 0;
    final end = endDate;
    if (end == null) return _reportedOverdueDays;
    final vietnam = instant.toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(vietnam.year, vietnam.month, vietnam.day);
    final expiry = DateTime.utc(end.year, end.month, end.day);
    final days = today.difference(expiry).inDays;
    return days > 0 ? days : 0;
  }

  int get overdueDays => overdueDaysAt(DateTime.now());
  bool get overdue =>
      isActive && (endDate != null ? overdueDays > 0 : _reportedOverdue);

  bool get hasHandoverIssue =>
      handoverIssueStatus == 'OPEN' || handoverIssueStatus == 'ARRANGED';

  bool get isRefunded => status == 'CANCELLED' && refundCompleted;
  bool get isActive => status == 'ACTIVE';
  String get displayUnit => (isActive || unitAssignmentConfirmed)
      ? 'Ngăn $unitCode'
      : 'Đang chờ quản lý xác nhận ngăn kho';
  bool get hasLateFeeDue => overdueFeeOutstanding > 0;

  /// Khách hàng có thể gia hạn thuê bất cứ lúc nào khi hợp đồng đang hoạt động
  bool get renewalNotYetOpen => false;

  double? get monthlyRate {
    if (rentalMonths == null || rentalMonths == 0) return null;
    return totalRentalFee / rentalMonths!;
  }

  String get id => bookingId;

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      refundBankCode: json['refundBankCode']?.toString() ?? '',
      refundAccountNumber: json['refundAccountNumber']?.toString() ?? '',
      refundAccountName: json['refundAccountName']?.toString() ?? '',
      checkoutNotes: json['checkoutNotes']?.toString() ?? '',
      refundCompleted: json['refundCompleted'] == true,
      customerName: json['customerName']?.toString() ?? '',
      serviceFee: (json['serviceFee'] as num?)?.toDouble(),
      agreement: RentalAgreement.fromJson(json),
      bookingId: json['bookingId']?.toString() ?? json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      handoverIssueStatus: json['handoverIssueStatus']?.toString() ?? '',
      handoverIssueReason: json['handoverIssueReason']?.toString() ?? '',
      handoverIssueDueAt: json['handoverIssueDueAt']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      unitAssignmentConfirmed: json['unitAssignmentConfirmed'] == true,
      facilityName: json['facilityName']?.toString() ?? '',
      facilityManagerName: json['facilityManagerName']?.toString() ?? '',
      facilityContactPhone: json['facilityContactPhone']?.toString() ?? '',
      facilityContactEmail: json['facilityContactEmail']?.toString() ?? '',
      facilityAddress: json['facilityAddress']?.toString() ??
          json['address']?.toString() ??
          '',
      typeName: json['unitTypeName']?.toString() ??
          json['typeName']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      totalRentalFee: (json['totalRentalFee'] as num?)?.toDouble() ??
          (json['rentalPrice'] as num?)?.toDouble() ??
          0.0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      hasActiveAccess:
          json['activeAccess'] == true || json['hasActiveAccess'] == true,
      dimensions: json['dimensions']?.toString() ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      rentalMonths: (json['rentalMonths'] as num?)?.toInt(),
      depositPaid: (json['depositPaid'] as num?)?.toDouble(),
      hasPendingExtension: json['hasPendingExtension'] == true,
      pendingExtraMonths: (json['pendingExtraMonths'] as num?)?.toInt(),
      pendingNewEndDate: json['pendingNewEndDate'] != null
          ? DateTime.tryParse(json['pendingNewEndDate'].toString())
          : null,
      pendingExtensionFee: (json['pendingExtensionFee'] as num?)?.toDouble(),
      renewalOpensDate: json['renewalOpensDate'] != null
          ? DateTime.tryParse(json['renewalOpensDate'].toString())
          : null,
      overdue: json['overdue'] == true,
      overdueDays: (json['overdueDays'] as num?)?.toInt() ?? 0,
      overdueFeeOutstanding:
          (json['overdueFeeOutstanding'] as num?)?.toDouble() ?? 0.0,
      accessDisabled: json['accessDisabled'] == true,
      scheduledReturnTime: json['scheduledReturnTime'] != null
          ? DateTime.tryParse(json['scheduledReturnTime'].toString())
          : null,
      openTime: json['openTime']?.toString(),
      closeTime: json['closeTime']?.toString(),
    );
  }

  String get operatingHours {
    final ot = openTime != null && openTime!.length >= 5
        ? openTime!.substring(0, 5)
        : '08:00';
    final ct = closeTime != null && closeTime!.length >= 5
        ? closeTime!.substring(0, 5)
        : '20:00';
    return '$ot - $ct';
  }

  int get openHour {
    if (openTime == null || openTime!.isEmpty) return 8;
    return int.tryParse(openTime!.split(':')[0]) ?? 8;
  }

  int get closeHour {
    if (closeTime == null || closeTime!.isEmpty) return 20;
    return int.tryParse(closeTime!.split(':')[0]) ?? 20;
  }
}
