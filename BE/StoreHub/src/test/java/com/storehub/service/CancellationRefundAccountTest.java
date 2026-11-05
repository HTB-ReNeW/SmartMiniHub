package com.storehub.service;

import com.storehub.dto.request.CancellationRefundAccountRequest;
import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.AppException;
import com.storehub.repository.*;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@ExtendWith(MockitoExtension.class)
class CancellationRefundAccountTest {
    @Mock UserRepository users;
    @Mock BookingRepository bookings;
    @Mock PaymentService payments;
    @Mock NotificationService notifications;
    @InjectMocks BookingServiceImpl service;
    private Booking setup(BookingStatus status) {
        User customer = User.builder().fullName("Nguyen Van An").build(); customer.setId(UUID.randomUUID());
        Facility facility = new Facility(); facility.setId(UUID.randomUUID());
        StorageUnit unit = StorageUnit.builder().facility(facility).unitCode("A-101").build();
        Booking booking = Booking.builder().customer(customer).storageUnit(unit).status(status).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId())).thenReturn(Optional.of(booking));
        return booking;
    }
    @Test void savesEnteredBeneficiaryBeforeCreatingRefund() {
        Booking booking = setup(BookingStatus.CONFIRMED);
        booking.setRefundAccountNumber("99999999");
        when(payments.refundOnCancellation(booking)).thenAnswer(inv -> {
            assertEquals("Vietcombank", booking.getRefundBankCode());
            assertEquals("0012345678", booking.getRefundAccountNumber());
            assertEquals("NGUYEN VAN AN", booking.getRefundAccountName());
            return BigDecimal.TEN;
        });
        service.cancelBooking(booking.getId(), "customer@test.com",
            new CancellationRefundAccountRequest(" Vietcombank ", "0012345678", " NGUYEN VAN AN "));
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        verify(bookings).save(booking);
    }
    @Test void cannotCancelPaidBookingWithoutAccount() {
        Booking booking = setup(BookingStatus.CONFIRMED);
        assertThrows(AppException.class, () -> service.cancelBooking(booking.getId(), "customer@test.com"));
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        verifyNoInteractions(payments);
        verify(bookings, never()).save(any());
    }
    @Test void unpaidCancellationStillNeedsNoRefundAccount() {
        Booking booking = setup(BookingStatus.PENDING_PAYMENT);
        service.cancelBooking(booking.getId(), "customer@test.com");
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        verifyNoInteractions(payments);
    }
}
