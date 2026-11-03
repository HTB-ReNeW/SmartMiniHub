package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;

import java.time.LocalDate;
import java.util.UUID;

public record FacilityBookingResponse(UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        LocalDate startDate,
        LocalDate endDate,
        UUID storageUnitId,
        String unitCode,
        UUID unitTypeId,
        String unitType,
        BookingStatus status,
        boolean unitAssignmentConfirmed,
        String unitStatus,
        String handoverIssueStatus,
        String handoverIssueReason,
        java.time.LocalDateTime handoverIssueDueAt,
        java.time.LocalDateTime scheduledCheckInTime,
        String handoverIssueResolutionNote,
        java.time.LocalDateTime createdAt
) {
    public FacilityBookingResponse(UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        LocalDate startDate,
        LocalDate endDate,
        UUID storageUnitId,
        String unitCode,
        UUID unitTypeId,
        String unitType,
        BookingStatus status,
        boolean unitAssignmentConfirmed,
        String unitStatus,
        String handoverIssueStatus,
        String handoverIssueReason,
        java.time.LocalDateTime handoverIssueDueAt,
        java.time.LocalDateTime scheduledCheckInTime,
        String handoverIssueResolutionNote) {
        this(bookingId, bookingCode, customerName, customerEmail, startDate, endDate, storageUnitId, unitCode, unitTypeId, unitType, status, unitAssignmentConfirmed, unitStatus, handoverIssueStatus, handoverIssueReason, handoverIssueDueAt, scheduledCheckInTime, handoverIssueResolutionNote, null);
    }

}
