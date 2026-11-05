package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.*;
import com.storehub.repository.*;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DepositDeductionTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock RefundRequestRepository refunds;
    @Mock FacilityPolicyRepository policies;
    @Mock DepositDeductionRepository deductions;
    @InjectMocks PaymentServiceImpl service;

    Booking booking() {
        Booking booking = Booking.builder().depositPaid(new BigDecimal("1000"))
                .startDate(LocalDate.now().plusDays(5)).build();
        booking.setId(UUID.randomUUID());
        return booking;
    }

    Payment captured(Booking booking) {
        Payment paid = Payment.builder().booking(booking).amount(new BigDecimal("1000"))
                .status(PaymentStatus.PAID).paymentType(PaymentType.DEPOSIT).transactionId("ORIGINAL")
                .gatewayCreateDate("20260101090000").build();
        paid.setId(UUID.randomUUID());
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)).thenReturn(Optional.of(paid));
        return paid;
    }

    @Test
    void partialDamageConvertsDepositWithoutCreatingANewCashReceipt() {
        Booking booking = booking();
        Payment original = captured(booking);
        when(payments.save(any())).thenAnswer(call -> call.getArgument(0));
        assertEquals(new BigDecimal("800"), service.refundDepositOnReturn(booking, new BigDecimal("200"), "Broken lock"));
        assertEquals(new BigDecimal("800"), booking.getDepositPaid()); // Still owed until refund completes.
        var deduction = ArgumentCaptor.forClass(DepositDeduction.class);
        verify(deductions).save(deduction.capture());
        assertEquals(new BigDecimal("200"), deduction.getValue().getAmount());
        assertEquals(original, deduction.getValue().getOriginalPayment());
        assertEquals("DAMAGE", deduction.getValue().getDeductionType());
        var refund = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(refund.capture());
        assertEquals(new BigDecimal("800"), refund.getValue().getDepositAmount());
        assertEquals(new BigDecimal("200"), refund.getValue().getDamageDeduction());
        verify(payments).save(argThat(p -> p.getTransactionId().startsWith("RF-")
                && p.getAmount().equals(new BigDecimal("800"))));
        assertEquals(PaymentStatus.PAID, original.getStatus());
    }

    @Test
    void fullDamageIsRecordedEvenWithoutAnyRefund() {
        Booking booking = booking();
        captured(booking);
        assertEquals(BigDecimal.ZERO, service.refundDepositOnReturn(booking, new BigDecimal("1000"), "Severe damage"));
        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        verify(deductions).save(argThat(d -> d.getAmount().equals(new BigDecimal("1000"))));
        verify(refunds, never()).save(any());
        verify(payments, never()).save(any());
    }

    @Test
    void retryCannotDeductTheSameOriginalDepositTwice() {
        Booking booking = booking();
        Payment paid = captured(booking);
        booking.setDepositPaid(new BigDecimal("800"));
        when(deductions.existsByOriginalPayment_IdAndDeductionType(paid.getId(), "DAMAGE")).thenReturn(true);
        when(refunds.existsByOriginalPayment_Id(paid.getId())).thenReturn(true);
        var error = assertThrows(AppException.class,
                () -> service.refundDepositOnReturn(booking, new BigDecimal("200"), "Damage"));
        assertEquals(ErrorCode.PAYMENT_ALREADY_PROCESSED, error.getErrorCode());
        assertEquals(new BigDecimal("800"), booking.getDepositPaid());
        verify(deductions, never()).save(any());
    }

    @Test
    void lateFeeIsDeductedFromDepositAndOldPaymentLinkIsVoided() {
        Booking booking = booking();
        captured(booking);
        Payment late = Payment.builder().amount(new BigDecimal("200")).status(PaymentStatus.PENDING)
                .transactionId("OD-OLD").gatewayCreateDate("20261104120000").build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(any(), any(), any(), any()))
                .thenReturn(java.util.List.of(late));
        assertEquals(BigDecimal.ZERO, service.deductReturnLateFeeFromDeposit(booking, BigDecimal.ZERO));
        assertEquals(new BigDecimal("800"), booking.getDepositPaid());
        assertEquals(new BigDecimal("200"), booking.getReturnLateFeeDeduction());
        assertNotNull(late.getVoidedAt());
        assertEquals(PaymentStatus.FAILED, late.getStatus());
        assertEquals(new BigDecimal("200"), late.getAmount());
        verify(deductions).save(argThat(d -> d.getDeductionType().equals("LATE_FEE")
                && d.getAmount().equals(new BigDecimal("200"))));
        assertEquals(new BigDecimal("800"), service.refundDepositOnReturn(booking));
    }

    @Test
    void onlyExcessAboveDepositRemainsPayableAndNoFakeCashReceiptIsCreated() {
        Booking booking = booking(); captured(booking);
        Payment late = Payment.builder().amount(new BigDecimal("1200"))
                .status(PaymentStatus.PENDING).transactionId("OLD").build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(any(), any(), any(), any()))
                .thenReturn(java.util.List.of(late));
        assertEquals(new BigDecimal("200"),service.deductReturnLateFeeFromDeposit(booking,BigDecimal.ZERO));
        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        verify(payments).save(argThat(p -> p != late && p.getAmount().equals(new BigDecimal("200"))
                && p.getStatus() == PaymentStatus.PENDING && p.getGatewayCreateDate() == null));
        verify(payments,never()).save(argThat(p -> p.getStatus() == PaymentStatus.PAID));
    }

    @Test
    void damageAndLateFeeHaveSeparateLedgerEventsWithoutOverdrawingDeposit() {
        Booking booking = booking(); captured(booking);
        Payment late = Payment.builder().amount(new BigDecimal("900"))
                .status(PaymentStatus.PENDING).transactionId("OLD").build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(any(), any(), any(), any()))
                .thenReturn(java.util.List.of(late));
        assertEquals(new BigDecimal("100"),service.deductReturnLateFeeFromDeposit(booking,new BigDecimal("200")));
        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        verify(deductions).save(argThat(d -> d.getDeductionType().equals("DAMAGE")
                && d.getAmount().equals(new BigDecimal("200"))));
        verify(deductions).save(argThat(d -> d.getDeductionType().equals("LATE_FEE")
                && d.getAmount().equals(new BigDecimal("800"))));
    }

    @Test
    void excessiveDamageCannotChangeTheBalance() {
        Booking booking = booking();
        assertThrows(AppException.class,
                () -> service.refundDepositOnReturn(booking, new BigDecimal("1001"), "Damage"));
        assertEquals(new BigDecimal("1000"), booking.getDepositPaid());
        verifyNoInteractions(deductions);
    }

    @Test
    void actualPolicyCalculationReplacesAnIncorrectOldFeeBeforeDeductingDeposit() {
        Booking b = booking(); b.setDepositPaid(new BigDecimal("500000"));
        b.setEndDate(LocalDate.of(2026,11,1));
        b.setReturnTime(java.time.LocalDateTime.of(2026,11,4,15,0));
        b.setOverdueDailyLateFee(new BigDecimal("50000")); b.setOverdueGraceDays(1);
        captured(b).setAmount(new BigDecimal("500000"));
        Payment stale = Payment.builder().amount(new BigDecimal("1500000"))
                .status(PaymentStatus.PENDING).transactionId("STALE").build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(b.getId(),PaymentType.EXTRA_CHARGE,
                com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE,List.of(PaymentStatus.PENDING,PaymentStatus.FAILED)))
                .thenReturn(List.of(stale));
        assertEquals(BigDecimal.ZERO,service.deductReturnLateFeeFromDeposit(b,BigDecimal.ZERO));
        assertEquals(new BigDecimal("400000"),b.getDepositPaid());
        assertEquals(new BigDecimal("100000"),b.getReturnLateFeeDeduction());
        assertNotNull(stale.getVoidedAt());
    }

    @Test
    void fullCancellationRetentionAlsoClosesTheDepositLiability() {
        Booking booking = booking();
        booking.setStorageUnit(StorageUnit.builder().facility(new Facility()).build());
        captured(booking);
        doReturn(Optional.empty()).when(payments).findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.RENTAL_FEE, PaymentStatus.PAID);
        when(pricing.calculateCancellationRefund(eq(booking), any(), any(), any())).thenReturn(BigDecimal.ZERO);
        assertEquals(BigDecimal.ZERO, service.refundOnCancellation(booking));
        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        verify(deductions).save(argThat(d -> d.getDeductionType().equals("CANCELLATION")));
        verify(refunds, never()).save(any());
    }
}
