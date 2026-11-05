package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.*;
import com.storehub.service.impl.RefundReviewService;
import com.storehub.exception.AppException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@ExtendWith(MockitoExtension.class)
class RefundReviewDetailsTest {
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock BookingRepository bookings;
    @Mock NotificationService notifications;
    @InjectMocks RefundReviewService service;
    final UUID facilityId=UUID.randomUUID(), refundId=UUID.randomUUID();
    final String email="facility@test.com";

    RefundRequest fixture() {
        when(users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(email,"FACILITY_MANAGER",facilityId)).thenReturn(true);
        Facility f=Facility.builder().name("StoreHub Thu Duc").build(); f.setId(facilityId);
        User customer=User.builder().fullName("Nguyễn Văn An").email("customer@test.com").phone("0901234567").build();
        Booking b=Booking.builder().bookingCode("BK-CANCEL").customer(customer).status(BookingStatus.CANCELLED)
                .totalRentalFee(new BigDecimal("2500000")).quotedManagementFee(new BigDecimal("50000"))
                .depositPaid(new BigDecimal("500000"))
                .storageUnit(StorageUnit.builder().unitCode("L-301").facility(f)
                    .unitType(UnitType.builder().typeName("Large").build()).build()).build(); b.setId(UUID.randomUUID());
        b.setCreatedAt(LocalDateTime.of(2026,11,4,12,32));
        var p=Payment.builder().paymentType(PaymentType.DEPOSIT).transactionId("TXN-123")
                .amount(new BigDecimal("500000")).build(); p.setId(UUID.randomUUID());
        var r=RefundRequest.builder().booking(b).originalPayment(p).refundPayment(Payment.builder().build())
                .status(RefundStatus.AWAITING_BANK_TRANSFER).amount(new BigDecimal("3050000"))
                .depositAmount(new BigDecimal("500000")).rentalAmount(new BigDecimal("2550000"))
                .bankCode("VCB").bankAccountName("NGUYEN VAN AN").bankAccountNumber("00123456789")
                .dueAt(LocalDateTime.of(2026,11,9,13,57)).build(); r.setId(refundId);
        r.setCreatedAt(LocalDateTime.of(2026,11,4,13,57));
        return r;
    }
    void expose(RefundRequest r) { when(refunds.findById(refundId)).thenReturn(Optional.of(r)); }

    @Test void cancellationBreakdownMatchesActualAmountAndCustomerProvidedAccount() {
        var r=fixture(); expose(r);
        var response=service.detail(facilityId,refundId,email); var d=response.details();
        assertEquals("Nguyễn Văn An",d.getCustomerName()); assertEquals("0901234567",d.getCustomerPhone());
        assertEquals("00123456789",response.bankAccountNumber()); assertEquals("CANCELLATION",d.getRefundKind());
        assertEquals(new BigDecimal("2500000"),d.getRentalRefund());
        assertEquals(new BigDecimal("50000"),d.getServiceFeeRefund());
        assertEquals(response.amount(),d.getRentalRefund().add(d.getServiceFeeRefund()).add(d.getDepositRefund()));
        assertEquals(100.0,d.getDepositRefundPercent());
    }
    @Test void legacyPaymentDoesNotInventAServiceFeeSplit() {
        var r=fixture(); r.getBooking().setQuotedManagementFee(null); expose(r);
        var d=service.detail(facilityId,refundId,email).details();
        assertFalse(d.isRentalServiceSplitKnown()); assertNull(d.getServiceFeeRefund());
        assertEquals(new BigDecimal("2550000"),d.getRentalRefund());
    }
    @Test void returnRefundShowsDepositDeductionsWithoutSubtractingThemTwice() {
        var r=fixture(); var b=r.getBooking(); b.setStatus(BookingStatus.COMPLETED);
        b.setReturnTime(LocalDateTime.of(2026,11,4,15,0)); b.setEndDate(LocalDate.of(2026,11,1));
        b.setReturnLateFeeDeduction(new BigDecimal("100000"));
        r.setAmount(new BigDecimal("400000")); r.setDepositAmount(r.getAmount()); r.setRentalAmount(BigDecimal.ZERO); expose(r);
        var response=service.detail(facilityId,refundId,email); var d=response.details();
        assertEquals("RETURN",d.getRefundKind()); assertEquals(3,d.getOverdueDays());
        assertEquals(new BigDecimal("100000"),d.getLateFeeDeduction());
        assertEquals(response.amount(),d.getDepositRefund());
    }
    @Test void extraChargeRefundIsNotMislabelledAsRentalOrDepositRefund() {
        var r=fixture(); r.getOriginalPayment().setPaymentType(PaymentType.EXTRA_CHARGE);
        r.setAmount(new BigDecimal("75000")); r.setRentalAmount(r.getAmount()); r.setDepositAmount(BigDecimal.ZERO); expose(r);
        var d=service.detail(facilityId,refundId,email).details();
        assertEquals("EXTRA_CHARGE",d.getRefundKind()); assertEquals(r.getAmount(),d.getExtraFeeRefund());
        assertEquals(0,d.getRentalRefund().signum()); assertEquals(0,d.getDepositRefund().signum());
    }
    @Test void detailCannotExposeAnotherFacilityRefund() {
        var r=fixture(); r.getBooking().getStorageUnit().getFacility().setId(UUID.randomUUID()); expose(r);
        assertThrows(AppException.class,() -> service.detail(facilityId,refundId,email));
    }
    @Test void unassignedManagerCannotReadRefundDetails() {
        assertThrows(AppException.class,() -> service.detail(facilityId,refundId,email));
        verifyNoInteractions(refunds);
    }
    @Test void serverFilterAndCountersCoverAllPagesWithTenRowsMaximum() {
        var r=fixture();
        when(refunds.findFilteredForManager(facilityId,RefundStatus.COMPLETED,"PENDING",PageRequest.of(3,10)))
                .thenReturn(new PageImpl<>(Collections.nCopies(10,r),PageRequest.of(3,10),40));
        when(refunds.countByBooking_StorageUnit_Facility_Id(facilityId)).thenReturn(51L);
        when(refunds.countByBooking_StorageUnit_Facility_IdAndStatus(facilityId,RefundStatus.COMPLETED)).thenReturn(11L);
        var page=service.listFiltered(facilityId,email,3,10,"PENDING");
        assertEquals(51,page.getAllCount()); assertEquals(40,page.getPendingCount()); assertEquals(11,page.getCompletedCount());
        assertEquals(40,page.getTotalElements()); assertEquals(4,page.getTotalPages());
        var json=new com.fasterxml.jackson.databind.ObjectMapper().findAndRegisterModules().valueToTree(page);
        assertEquals(40,json.path("pendingCount").asLong());
        assertThrows(AppException.class,() -> service.listFiltered(facilityId,email,0,11,"ALL"));
        assertThrows(AppException.class,() -> service.listFiltered(facilityId,email,0,10,"UNKNOWN"));
    }
    @Test void bankConfirmationStoresActualActorReferenceAndFullNotes() {
        var r=fixture();
        when(refunds.lockById(refundId)).thenReturn(Optional.of(r));
        when(bookings.lockById(r.getBooking().getId())).thenReturn(Optional.of(r.getBooking()));
        var actor=User.builder().fullName("Facility Manager").build();
        when(users.findByEmail(email)).thenReturn(Optional.of(actor));
        String notes="Nội dung chuyển khoản ".repeat(20);
        service.confirmBankTransfer(facilityId,refundId,email,
                com.storehub.dto.request.ConfirmBankTransferRequest.builder().transferReference("BANK-REAL-123").notes(notes).build());
        assertEquals(RefundStatus.COMPLETED,r.getStatus()); assertEquals(actor,r.getConfirmedByManager());
        assertEquals(notes,r.getTransferNotes()); assertEquals("BANK-REAL-123",r.getTransferReference());
        assertTrue(r.getRefundPayment().getNote().length()<=100);
    }
}
