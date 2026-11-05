package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.*;
import com.storehub.repository.*;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.LocalDateTime;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeferredPaymentBookingTest {
    @Mock UserRepository users;
    @Mock BookingRepository bookings;
    @InjectMocks BookingServiceImpl service;

    private Booking setup(BookingStatus status, LocalDateTime expiry) {
        User customer = new User(); customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().customer(customer).status(status).expiresAt(expiry).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmailForUpdate("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId())).thenReturn(Optional.of(booking));
        return booking;
    }

    @Test
    void refusesASecondDeferredBookingWhileEarlierOneIsUnpaid() {
        Booking booking = setup(BookingStatus.PENDING_PAYMENT, LocalDateTime.now().plusMinutes(20));
        when(bookings.hasOtherDeferredPayment(eq(booking.getCustomer().getId()), eq(booking.getId()), any()))
            .thenReturn(true);
        AppException error = assertThrows(AppException.class, () -> service.deferPayment(booking.getId(), "customer@test.com"));
        assertEquals(ErrorCode.DEFERRED_PAYMENT_EXISTS, error.getErrorCode());
        assertFalse(booking.getPaymentDeferred());
        verify(bookings, never()).save(any());
    }

    @Test
    void permitsDeferralOnceNoEarlierUnpaidUnexpiredDeferredBookingRemains() {
        Booking booking = setup(BookingStatus.PENDING_PAYMENT, LocalDateTime.now().plusMinutes(20));
        service.deferPayment(booking.getId(), "customer@test.com");
        assertTrue(booking.getPaymentDeferred());
        var order = inOrder(users, bookings);
        order.verify(users).findByEmailForUpdate("customer@test.com");
        order.verify(bookings).lockByIdAndCustomerId(booking.getId(), booking.getCustomer().getId());
        order.verify(bookings).hasOtherDeferredPayment(eq(booking.getCustomer().getId()), eq(booking.getId()), any());
        order.verify(bookings).save(booking);
    }

    @Test
    void refusesExpiredAndAlreadyPaidBookings() {
        Booking booking = setup(BookingStatus.PENDING_PAYMENT, LocalDateTime.now().minusSeconds(1));
        assertThrows(AppException.class, () -> service.deferPayment(booking.getId(), "customer@test.com"));
        booking.setExpiresAt(LocalDateTime.now().plusMinutes(20));
        booking.setStatus(BookingStatus.CONFIRMED);
        assertThrows(AppException.class, () -> service.deferPayment(booking.getId(), "customer@test.com"));
        verify(bookings, never()).save(any());
        verify(bookings, never()).hasOtherDeferredPayment(any(), any(), any());
    }
}
