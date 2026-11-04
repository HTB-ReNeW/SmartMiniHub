package com.storehub.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Data @Builder
public class RefundDetailsResponse {
    private String customerName, customerEmail, customerPhone, facilityName, unitCode, unitType;
    private String refundKind, reason;
    private LocalDateTime bookedAt, requestedAt, returnedAt, completedAt;
    private LocalDate startDate, endDate;
    private BigDecimal depositBefore, depositRefund, rentalRefund, serviceFeeRefund, extraFeeRefund;
    private BigDecimal totalRentalFee, serviceFee;
    private Integer rentalMonths;
    private boolean rentalServiceSplitKnown;
    private BigDecimal lateFeeDeduction, damageDeduction, cancellationDeduction;
    private Double depositRefundPercent;
    private long overdueDays;
    private String confirmedByName, transferNotes;
    private String termsVersion, termsContentSnapshot, prohibitedItemsSnapshot;
    private Boolean termsAccepted, prohibitedItemsAccepted;
    private LocalDateTime termsAcceptedAt;
    private List<String> contractPhotos;
    private RentalPolicyResponse rentalPolicy;
}
