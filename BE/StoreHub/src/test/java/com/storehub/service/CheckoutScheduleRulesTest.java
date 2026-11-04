package com.storehub.service;

import com.storehub.common.CheckoutScheduleWindow;
import com.storehub.dto.request.CheckoutRequest;
import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.*;
import com.storehub.repository.*;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CheckoutScheduleRulesTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock ActivityLogService logs;
    @Mock NotificationService notifications;
    @InjectMocks CustomerStorageServiceImpl service;
    Booking booking;
    final LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));

    @BeforeEach
    void setup() {
        User customer = User.builder().fullName("Nguyen Van An").build(); customer.setId(UUID.randomUUID());
        Facility facility = Facility.builder().openTime(LocalTime.of(8, 0)).closeTime(LocalTime.of(20, 0)).build();
        facility.setId(UUID.randomUUID());
        booking = Booking.builder().customer(customer).bookingCode("BK-RETURN").status(BookingStatus.ACTIVE)
                .storageUnit(StorageUnit.builder().unitCode("S-101").facility(facility).build())
                .endDate(today.minusDays(1)).returnNoticeDays(3).overdueFeeAccrued(BigDecimal.valueOf(50000))
                .accessDisabledAt(today.atStartOfDay()).sealingPendingAt(today.atStartOfDay())
                .sealingApprovedAt(today.atStartOfDay()).build();
        booking.setId(UUID.randomUUID());
        lenient().when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        lenient().when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId())).thenReturn(Optional.of(booking));
    }

    private CheckoutRequest request(LocalDateTime time) {
        CheckoutRequest request = new CheckoutRequest();
        request.setScheduledReturnTime(time); request.setBankCode(" VCB ");
        request.setBankAccountNumber("0012345678"); request.setBankAccountName(" NGUYEN VAN AN ");
        request.setNotes(" Goi truoc 15 phut "); return request;
    }

    @Test
    void overdueCustomerCanReturnDespitePinAndSealingAndLongNotice() {
        LocalDate end = booking.getEndDate();
        LocalDateTime disabled = booking.getAccessDisabledAt(), sealed = booking.getSealingApprovedAt();
        service.requestCheckout(booking.getId(), "customer@test.com", request(today.plusDays(1).atTime(10, 0)));
        assertEquals(end, booking.getEndDate());
        assertEquals(BookingStatus.ACTIVE, booking.getStatus());
        assertEquals(disabled, booking.getAccessDisabledAt());
        assertEquals(sealed, booking.getSealingApprovedAt());
        assertEquals(BigDecimal.valueOf(50000), booking.getOverdueFeeAccrued());
        assertEquals("0012345678", booking.getRefundAccountNumber());
        assertEquals("Goi truoc 15 phut", booking.getCheckoutNotes());
    }

    @Test
    void directApiCallCannotScheduleFarAfterExpiry() {
        var error = assertThrows(AppException.class, () -> service.requestCheckout(booking.getId(), "customer@test.com",
                request(today.plusDays(30).atTime(10, 0))));
        assertEquals(ErrorCode.CHECKOUT_SCHEDULE_OUT_OF_RANGE, error.getErrorCode());
        verify(bookings, never()).save(any()); verifyNoInteractions(notifications);
    }

    @Test
    void pastAppointmentMustBeReplacedBeforeSaving() {
        booking.setScheduledReturnTime(today.minusDays(1).atTime(10, 0));
        var error = assertThrows(AppException.class, () -> service.requestCheckout(booking.getId(), "customer@test.com",
                request(booking.getScheduledReturnTime())));
        assertEquals(ErrorCode.CHECKOUT_TIME_IN_PAST, error.getErrorCode());
    }

    @Test
    void changingTimeCancelsOldStaffAssignmentAndNotifiesBothManagerAndStaff() {
        User staff = new User(); staff.setId(UUID.randomUUID());
        booking.setAssignedCheckOutStaff(staff); booking.setScheduledReturnTime(today.atTime(10, 0));
        service.requestCheckout(booking.getId(), "customer@test.com", request(today.plusDays(1).atTime(10, 0)));
        assertNull(booking.getAssignedCheckOutStaff());
        verify(notifications).notifyFacilityManager(any(), contains("phân công lại"), anyString(), any(), eq(booking.getId()), anyString());
        verify(notifications).notifyUser(eq(staff), anyString(), contains("Phân công cũ đã hủy"), any(), any(), anyString(), any());
    }

    @Test
    void editingBankOrNotesWithoutChangingTimeKeepsAssignedStaff() {
        User staff = new User(); staff.setId(UUID.randomUUID());
        booking.setAssignedCheckOutStaff(staff); booking.setScheduledReturnTime(today.plusDays(1).atTime(10, 0));
        service.requestCheckout(booking.getId(), "customer@test.com", request(booking.getScheduledReturnTime()));
        assertSame(staff, booking.getAssignedCheckOutStaff());
    }

    @Test
    void noticeIsCappedAtRentalEndAndWaivedForExpiredContracts() {
        booking.setEndDate(today.plusDays(1));
        var window = CheckoutScheduleWindow.forBooking(booking, today);
        assertEquals(today.plusDays(1), window.earliest());
        assertEquals(today.plusDays(1), window.latest());
        booking.setEndDate(today.plusDays(10));
        window = CheckoutScheduleWindow.forBooking(booking, today);
        assertEquals(today.plusDays(3), window.earliest());
        assertFalse(window.contains(today.plusDays(11)));
    }

    @Test
    void unexpiredBookingCannotBookAfterItsEndDateOrIgnoreNotice() {
        booking.setEndDate(today.plusDays(10));
        var error = assertThrows(AppException.class, () -> service.requestCheckout(booking.getId(), "customer@test.com",
                request(today.plusDays(11).atTime(10, 0))));
        assertEquals(ErrorCode.CHECKOUT_SCHEDULE_OUT_OF_RANGE, error.getErrorCode());
        error = assertThrows(AppException.class, () -> service.requestCheckout(booking.getId(), "customer@test.com",
                request(today.plusDays(1).atTime(10, 0))));
        assertEquals(ErrorCode.RETURN_NOTICE_NOT_SATISFIED, error.getErrorCode());
    }
}
