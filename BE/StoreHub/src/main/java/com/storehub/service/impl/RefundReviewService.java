package com.storehub.service.impl;

import com.storehub.dto.request.RefundGatewayMetadataRequest;
import com.storehub.common.PageResponse;
import com.storehub.dto.response.RefundRequestResponse;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.RefundStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.scheduler.RefundDispatcher;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RefundReviewService {
    private final RefundRequestRepository refunds;
    private final UserRepository users;
    private final RefundDispatcher dispatcher;
    private final com.storehub.repository.BookingRepository bookings;
    private final com.storehub.service.NotificationService notificationService;

    public void reconcile(UUID facilityId, UUID refundId, String managerEmail) {
        requireManager(facilityId, managerEmail);
        // The transaction is closed before the outbound gateway call.
        verifyRefundFacility(facilityId, refundId);
        dispatcher.reconcile(refundId);
    }

    public void verifyRefundFacility(UUID facilityId, UUID id) {
        if (!refunds.existsByIdAndBooking_StorageUnit_Facility_Id(id, facilityId)) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
    }

    @Transactional(readOnly = true)
    public PageResponse<RefundRequestResponse> list(UUID facilityId, String managerEmail,
                                                     int page, int size) {
        requireManager(facilityId, managerEmail);
        if (page < 0 || size < 1 || size > 100) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        return PageResponse.from(refunds.findForManager(facilityId, RefundStatus.COMPLETED,
                LocalDateTime.now(), PageRequest.of(page, size)).map(this::response));
    }

    @Transactional(readOnly = true, isolation = org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public com.storehub.dto.response.RefundReviewPageResponse listFiltered(UUID facilityId, String email,
            int page, int size, String filter) {
        requireManager(facilityId,email);
        if(page < 0 || size < 1 || size > 10 || !java.util.Set.of("ALL","PENDING","COMPLETED").contains(filter)) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        var rows=refunds.findFilteredForManager(facilityId,RefundStatus.COMPLETED,filter,PageRequest.of(page,size));
        return new com.storehub.dto.response.RefundReviewPageResponse(rows.map(this::response),
                refunds.countByBooking_StorageUnit_Facility_Id(facilityId),
                refunds.countByBooking_StorageUnit_Facility_IdAndStatus(facilityId,RefundStatus.COMPLETED));
    }

    @Transactional(readOnly = true)
    public RefundRequestResponse detail(UUID facilityId, UUID refundId, String email) {
        requireManager(facilityId,email);
        var refund=refunds.findById(refundId).orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        if(!facilityId.equals(refund.getBooking().getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
        return response(refund);
    }

    @Transactional
    public RefundRequestResponse provideMetadata(UUID facilityId, UUID refundId,
                                                  String managerEmail, RefundGatewayMetadataRequest details) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        if (refund.getStatus() != RefundStatus.MISSING_METADATA
                && refund.getStatus() != RefundStatus.REJECTED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (details.getOriginalAmount().compareTo(refund.getAmount()) < 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (refund.getStatus() == RefundStatus.REJECTED) rotateRequestId(refund);
        Payment original = refund.getOriginalPayment();
        original.setGatewayCreateDate(details.getTransactionDate());
        original.setGatewayTransactionNo(details.getTransactionNo());
        original.setGatewayAmount(details.getOriginalAmount());
        refund.setStatus(RefundStatus.QUEUED);
        refund.setUpdatedStatusAt(LocalDateTime.now());
        return response(refund);
    }

    @Transactional
    public RefundRequestResponse retryRejected(UUID facilityId, UUID refundId, String managerEmail) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        if (refund.getStatus() != RefundStatus.REJECTED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        rotateRequestId(refund);
        refund.setStatus(RefundStatus.QUEUED);
        refund.setUpdatedStatusAt(LocalDateTime.now());
        return response(refund);
    }

    @Transactional
    public RefundRequestResponse confirmBankTransfer(UUID facilityId, UUID refundId,
                                                     String managerEmail, com.storehub.dto.request.ConfirmBankTransferRequest request) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        // Cho phép quản lý xác nhận chuyển khoản hoàn cọc cho AWAITING_BANK_TRANSFER,
        // hoặc khi giao dịch hoàn tiền online bị treo/chờ xác nhận (AWAITING_CONFIRMATION, NEEDS_REVIEW, REJECTED)
        // để quản lý có thể hoàn trả thủ công và giải phóng đơn cho khách hàng.
        if (refund.getStatus() != RefundStatus.AWAITING_BANK_TRANSFER
                && refund.getStatus() != RefundStatus.AWAITING_CONFIRMATION
                && refund.getStatus() != RefundStatus.NEEDS_REVIEW
                && refund.getStatus() != RefundStatus.REJECTED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        LocalDateTime now = LocalDateTime.now();
        refund.setStatus(RefundStatus.COMPLETED);
        refund.setCompletedAt(now);
        refund.setUpdatedStatusAt(now);
        refund.setTransferReference(request.getTransferReference());
        refund.setConfirmedByManager(users.findByEmail(managerEmail).orElse(null));
        refund.setTransferNotes(request.getNotes());

        com.storehub.entity.Booking booking = bookings.lockById(refund.getBooking().getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));
        if (booking != null && booking.getDepositPaid() != null) {
            java.math.BigDecimal depositRemaining = booking.getDepositPaid().subtract(refund.getDepositAmount());
            if (depositRemaining.signum() < 0) throw new AppException(ErrorCode.INVALID_REQUEST);
            booking.setDepositPaid(depositRemaining);
        }

        Payment original = refund.getOriginalPayment();
        if (original != null) {
            java.math.BigDecimal remaining = original.getAmount().subtract(refund.getDepositAmount());
            if (remaining.signum() <= 0) {
                original.setStatus(com.storehub.enums.PaymentStatus.REFUNDED);
            }
        }

        Payment refundPayment = refund.getRefundPayment();
        if (refundPayment != null) {
            refundPayment.setStatus(com.storehub.enums.PaymentStatus.REFUNDED);
            refundPayment.setPaymentMethod("BANK_TRANSFER");
            refundPayment.setPaymentTime(now);
            if (request.getNotes() != null && !request.getNotes().isBlank()) {
                String existingNote = refundPayment.getNote() != null ? refundPayment.getNote() : "";
                String note=existingNote + " | Ref: " + request.getTransferReference();
                refundPayment.setNote(note.substring(0,Math.min(note.length(),100)));
            }
        }

        if (booking != null && booking.getCustomer() != null) {
            String unitCode = booking.getStorageUnit() != null ? booking.getStorageUnit().getUnitCode() : "";
            com.storehub.entity.Facility facility = booking.getStorageUnit() != null ? booking.getStorageUnit().getFacility() : null;
            notificationService.notifyUser(
                    booking.getCustomer(),
                    "Hoàn tiền thành công",
                    "Khoản hoàn tiền " + refund.getAmount().toPlainString() + " ₫ cho đơn " + booking.getBookingCode()
                            + (unitCode.isEmpty() ? "" : " (Ngăn " + unitCode + ")")
                            + " đã được cơ sở chuyển khoản thành công. Mã tham chiếu: " + request.getTransferReference() + ".",
                    com.storehub.enums.NotificationType.REFUND_COMPLETED,
                    booking.getId(),
                    "BOOKING",
                    facility
            );

            notificationService.notifyRole(
                    "BUSINESS_MANAGER",
                    "Hoàn tiền hoàn tất - " + (facility != null ? facility.getName() : ""),
                    "Cơ sở " + (facility != null ? facility.getName() : "") + " đã hoàn số tiền "
                            + refund.getAmount().toPlainString() + " ₫ cho đơn " + booking.getBookingCode()
                            + " (Mã GD: " + request.getTransferReference() + ").",
                    com.storehub.enums.NotificationType.REFUND_COMPLETED,
                    booking.getId(),
                    "BOOKING"
            );
        }

        return response(refund);
    }

    private void rotateRequestId(RefundRequest refund) {
        String requestId = UUID.randomUUID().toString().replace("-", "").toUpperCase();
        refund.setRequestId(requestId);
        refund.getRefundPayment().setTransactionId("RF-" + requestId);
        refund.setGatewayResponseCode(null);
        refund.setGatewayTransactionStatus(null);
    }

    private RefundRequest requireRefund(UUID facilityId, UUID id) {
        RefundRequest refund = refunds.lockById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        if (!facilityId.equals(refund.getBooking().getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
        return refund;
    }

    private void requireManager(UUID facilityId, String email) {
        if (!users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(
                email, "FACILITY_MANAGER", facilityId)) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }
    }

    private RefundRequestResponse response(RefundRequest refund) {
        boolean unresolved = refund.getStatus() != RefundStatus.COMPLETED;
        return new RefundRequestResponse(
                refund.getId(),
                refund.getBooking().getId(),
                refund.getBooking().getBookingCode(),
                refund.getOriginalPayment() != null ? refund.getOriginalPayment().getTransactionId() : null,
                refund.getRequestId(),
                refund.getAmount(),
                refund.getStatus(),
                refund.getGatewayResponseCode(),
                refund.getGatewayTransactionStatus(),
                refund.getDueAt(),
                unresolved && refund.getDueAt() != null && refund.getDueAt().isBefore(LocalDateTime.now()),
                refund.getDamageDeduction() != null ? refund.getDamageDeduction() : java.math.BigDecimal.ZERO,
                refund.getBankCode(),
                refund.getBankAccountNumber(),
                refund.getBankAccountName(),
                refund.getTransferReference(),
                details(refund)
        );
    }

    private static java.math.BigDecimal value(java.math.BigDecimal amount) {
        return amount == null ? java.math.BigDecimal.ZERO : amount;
    }

    private com.storehub.dto.response.RefundDetailsResponse details(RefundRequest r) {
        var b=r.getBooking(); var original=r.getOriginalPayment();
        var customer=b.getCustomer(); var unit=b.getStorageUnit();
        var facility=unit == null ? null : unit.getFacility();
        var zero=java.math.BigDecimal.ZERO;
        boolean extra=original != null && original.getPaymentType() == com.storehub.enums.PaymentType.EXTRA_CHARGE;
        boolean cancellation=!extra && b.getStatus() == com.storehub.enums.BookingStatus.CANCELLED && b.getHandoverTime() == null;
        boolean returned=!extra && !cancellation && b.getReturnTime() != null && value(r.getRentalAmount()).signum() == 0;
        String kind=extra ? "EXTRA_CHARGE" : cancellation ? "CANCELLATION" : returned ? "RETURN" : "OTHER";
        var depositBefore=extra ? zero : original == null ? null : original.getAmount();
        var rental=value(r.getRentalAmount());
        var fee=b.getQuotedManagementFee();
        boolean splitKnown=extra || rental.signum() == 0 || (fee != null && b.getTotalRentalFee() != null
                && rental.compareTo(b.getTotalRentalFee().add(fee)) == 0);
        var serviceRefund=extra || rental.signum() == 0 ? zero : splitKnown ? fee : null;
        var rentalRefund=extra ? zero : splitKnown ? rental.subtract(value(serviceRefund)) : rental;
        Double percentage=depositBefore != null && depositBefore.signum() > 0
                ? value(r.getDepositAmount()).multiply(java.math.BigDecimal.valueOf(100))
                    .divide(depositBefore,2,java.math.RoundingMode.HALF_UP).doubleValue() : null;
        String reason=extra ? "Hoàn phí phát sinh theo giao dịch gốc"
                : cancellation ? (b.getHandoverIssueReportedAt() != null ? "Hủy trước nhận kho có ghi nhận sự cố bàn giao tại cơ sở"
                    : "Hủy đơn trước khi nhận kho")
                : returned ? "Hoàn cọc sau khi nhân viên nhận lại kho" : "Hoàn tiền theo đối soát giao dịch";
        return com.storehub.dto.response.RefundDetailsResponse.builder()
                .customerName(customer == null ? null : customer.getFullName())
                .customerEmail(customer == null ? null : customer.getEmail())
                .customerPhone(customer == null ? null : customer.getPhone())
                .facilityName(facility == null ? null : facility.getName())
                .unitCode(unit == null ? null : unit.getUnitCode())
                .unitType(unit == null || unit.getUnitType() == null ? null : unit.getUnitType().getTypeName())
                .refundKind(kind).reason(reason).bookedAt(b.getCreatedAt()).requestedAt(r.getCreatedAt())
                .returnedAt(b.getReturnTime()).completedAt(r.getCompletedAt()).startDate(b.getStartDate()).endDate(b.getEndDate())
                .depositBefore(depositBefore).depositRefund(value(r.getDepositAmount()))
                .rentalRefund(rentalRefund).serviceFeeRefund(serviceRefund).rentalServiceSplitKnown(splitKnown)
                .extraFeeRefund(extra ? rental : zero)
                .totalRentalFee(b.getTotalRentalFee()).serviceFee(b.getQuotedManagementFee()).rentalMonths(b.getRentalMonths())
                .lateFeeDeduction(returned ? value(b.getReturnLateFeeDeduction()) : zero)
                .damageDeduction(value(r.getDamageDeduction()))
                .cancellationDeduction(cancellation && depositBefore != null ? depositBefore.subtract(value(r.getDepositAmount())).max(zero) : zero)
                .depositRefundPercent(percentage)
                .overdueDays(returned && b.getEndDate() != null ? Math.max(0,java.time.temporal.ChronoUnit.DAYS.between(b.getEndDate(),b.getReturnTime().toLocalDate())) : 0)
                .confirmedByName(r.getConfirmedByManager() == null ? null : r.getConfirmedByManager().getFullName())
                .transferNotes(r.getTransferNotes()).termsVersion(b.getTermsVersion())
                .termsContentSnapshot(b.getTermsContentSnapshot()).prohibitedItemsSnapshot(b.getProhibitedItemsSnapshot())
                .termsAccepted(b.getTermsAccepted()).prohibitedItemsAccepted(b.getProhibitedItemsAccepted())
                .termsAcceptedAt(b.getTermsAcceptedAt()).contractPhotos(b.getContractPhotos())
                .rentalPolicy(com.storehub.dto.response.RentalPolicyResponse.from(b)).build();
    }
}
