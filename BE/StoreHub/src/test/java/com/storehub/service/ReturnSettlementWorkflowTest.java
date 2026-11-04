package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.*;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@ExtendWith(MockitoExtension.class)
class ReturnSettlementWorkflowTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock HandoverRecordRepository records;
    @Mock NotificationRepository notificationRepository;
    @Mock NotificationService notifications;
    @Mock ActivityLogService logs;
    @InjectMocks OverdueScheduler scheduler;
    @Spy @InjectMocks PaymentServiceImpl service;

    Booking booking(BookingStatus status) {
        Booking b = Booking.builder().status(status).bookingCode("BK-RETURN")
                .endDate(LocalDate.of(2026,11,1)).overdueDailyLateFee(new BigDecimal("75"))
                .overdueGraceDays(1).overdueAccessDisableDays(3).overdueSealingDays(7)
                .depositPaid(new BigDecimal("500")).customer(new User())
                .storageUnit(StorageUnit.builder().facility(new Facility()).unitCode("S-101").build()).build();
        b.setId(UUID.randomUUID()); return b;
    }

    @Test
    void expiryDayVoidsOnlyUnpaidPrematureFeesAndRejectsAnOldGatewayLink() {
        Booking b = booking(BookingStatus.ACTIVE);
        Payment p = Payment.builder().booking(b).status(PaymentStatus.PENDING)
                .transactionId("OD-OLD").amount(new BigDecimal("1500000"))
                .gatewayCreateDate("20261101120000").build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                b.getId(),PaymentType.EXTRA_CHARGE,OVERDUE_LATE_FEE,
                List.of(PaymentStatus.PENDING,PaymentStatus.FAILED))).thenReturn(List.of(p));
        assertFalse(scheduler.accrueOutstandingForCheckout(b, b.getEndDate().atTime(23,59)));
        assertNotNull(p.getVoidedAt());
        assertEquals(PaymentStatus.FAILED,p.getStatus());
        assertEquals(new BigDecimal("1500000"),p.getAmount());
        assertEquals(BigDecimal.ZERO,b.getOverdueFeeAccrued());
    }

    @Test
    void noMoreFeesAccrueAfterPhysicalReturnEvenIfPaymentIsMuchLater() {
        Booking b = booking(BookingStatus.COMPLETED);
        b.setReturnTime(LocalDateTime.of(2026,11,4,15,0));
        b.setOverdueFeeAccrued(new BigDecimal("150.00"));
        scheduler.accrueOutstandingForCheckout(b,LocalDateTime.of(2027,11,4,15,0));
        assertEquals(new BigDecimal("150.00"),b.getOverdueFeeAccrued());
        verify(payments,never()).save(any());
    }

    @Test
    void finalLateFeePaymentAutomaticallyProcessesDepositUsingSavedInspectionDamage() {
        Booking b = booking(BookingStatus.COMPLETED);
        b.setReturnTime(LocalDateTime.of(2026,11,4,15,0));
        Payment p = Payment.builder().booking(b).transactionId("OD-PAY")
                .paymentType(PaymentType.EXTRA_CHARGE).note(OVERDUE_LATE_FEE)
                .status(PaymentStatus.PENDING).amount(new BigDecimal("150")).build();
        Payment deposit = Payment.builder().booking(b).paymentType(PaymentType.DEPOSIT)
                .status(PaymentStatus.PAID).amount(new BigDecimal("500")).build();
        deposit.setId(UUID.randomUUID());
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                b.getId(),PaymentType.DEPOSIT,PaymentStatus.PAID)).thenReturn(Optional.of(deposit));
        when(records.findByBookingIdOrderByRecordedAtDesc(b.getId())).thenReturn(List.of(
                HandoverRecord.builder().recordType("RETURN").damageFee(new BigDecimal("100"))
                        .damageReason("Broken panel").build()));
        doReturn(new BigDecimal("400")).when(service).refundDepositOnReturn(
                b,new BigDecimal("100"),"Broken panel");
        ReflectionTestUtils.invokeMethod(service,"processPaymentConfirmation",p,b);
        assertEquals(PaymentStatus.PAID,p.getStatus());
        verify(service).refundDepositOnReturn(b,new BigDecimal("100"),"Broken panel");
        verify(notifications).notifyFacilityManager(any(),anyString(),contains("400"),
                eq(NotificationType.CHECKOUT_INSPECTED),eq(b.getId()),eq("BOOKING"));
    }

    @Test
    void anotherOutstandingFeeDefersTheDepositRefund() {
        Booking b = booking(BookingStatus.COMPLETED); b.setReturnTime(LocalDateTime.now());
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                b.getId(),PaymentType.EXTRA_CHARGE,OVERDUE_LATE_FEE,
                List.of(PaymentStatus.PENDING,PaymentStatus.FAILED))).thenReturn(List.of(
                        Payment.builder().amount(new BigDecimal("75")).build()));
        ReflectionTestUtils.invokeMethod(service,"finishReturnRefundAfterSettlement",b);
        verifyNoInteractions(records,refunds,notifications);
    }
}
