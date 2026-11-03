package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/** Hợp đồng thuê (booking CONFIRMED / ACTIVE) để Facility Manager theo dõi. */
public record FacilityContractResponse(UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        String unitCode,
        String unitType,
        LocalDate startDate,
        LocalDate endDate,
        Integer rentalMonths,
        BookingStatus status,
        BigDecimal depositPaid,
        BigDecimal totalRentalFee,
        LocalDateTime returnTime,
        boolean overdue,
        long overdueDays,
        BigDecimal overdueFeeAccrued,
        boolean accessDisabled,
        boolean sealingPending,
        BigDecimal pendingExtensionFee,
        boolean sealingApproved,
        String termsVersion,
        String termsContentSnapshot,
        String prohibitedItemsSnapshot,
        Boolean termsAccepted,
        Boolean prohibitedItemsAccepted,
        LocalDateTime termsAcceptedAt,
        java.util.List<String> contractPhotos,
        BigDecimal serviceFee,
        java.time.LocalDateTime createdAt
) {
    public FacilityContractResponse(UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        String unitCode,
        String unitType,
        LocalDate startDate,
        LocalDate endDate,
        Integer rentalMonths,
        BookingStatus status,
        BigDecimal depositPaid,
        BigDecimal totalRentalFee,
        LocalDateTime returnTime,
        boolean overdue,
        long overdueDays,
        BigDecimal overdueFeeAccrued,
        boolean accessDisabled,
        boolean sealingPending,
        BigDecimal pendingExtensionFee,
        boolean sealingApproved,
        String termsVersion,
        String termsContentSnapshot,
        String prohibitedItemsSnapshot,
        Boolean termsAccepted,
        Boolean prohibitedItemsAccepted,
        LocalDateTime termsAcceptedAt,
        java.util.List<String> contractPhotos,
        BigDecimal serviceFee) {
        this(bookingId, bookingCode, customerName, customerEmail, unitCode, unitType, startDate, endDate, rentalMonths, status, depositPaid, totalRentalFee, returnTime, overdue, overdueDays, overdueFeeAccrued, accessDisabled, sealingPending, pendingExtensionFee, sealingApproved, termsVersion, termsContentSnapshot, prohibitedItemsSnapshot, termsAccepted, prohibitedItemsAccepted, termsAcceptedAt, contractPhotos, serviceFee, null);
    }
}
