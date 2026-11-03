package com.storehub.service;

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
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@ExtendWith(MockitoExtension.class)
class CancellationQuoteTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock PaymentRepository payments;
    @Mock PricingService pricing;
    @InjectMocks BookingServiceImpl service;

    @Test
    void quotesPartialDepositAndAllPaidRentUsingServerTime() {
        User customer = new User(); customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().customer(customer).status(BookingStatus.CONFIRMED)
            .depositPaid(new BigDecimal("500000")).startDate(LocalDate.now().plusDays(5)).build();
        booking.setId(UUID.randomUUID()); booking.setCreatedAt(LocalDateTime.now().minusDays(2));
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.findById(booking.getId())).thenReturn(Optional.of(booking));
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
            booking.getId(), PaymentType.RENTAL_FEE, PaymentStatus.PAID))
            .thenReturn(Optional.of(Payment.builder().amount(new BigDecimal("3000000")).build()));
        when(pricing.calculateCancellationRefund(eq(booking), eq(new BigDecimal("500000")), any(), any()))
            .thenReturn(new BigDecimal("250000"));
        LocalDateTime before = LocalDateTime.now();
        var result = service.cancellationQuote(booking.getId(), "customer@test.com");
        assertEquals(new BigDecimal("3250000"), result.get("totalRefund"));
        assertEquals(new BigDecimal("3000000"), result.get("rentalRefund"));
        assertEquals(booking.getCreatedAt().plusHours(24), result.get("deadline"));
        assertFalse(((LocalDateTime) result.get("evaluatedAt")).isBefore(before));
        verify(bookings, never()).save(any());
    }

    @Test
    void customerCannotQuoteAnotherCustomersBooking() {
        User customer = new User(); customer.setId(UUID.randomUUID());
        User owner = new User(); owner.setId(UUID.randomUUID());
        Booking booking = Booking.builder().customer(owner).status(BookingStatus.CONFIRMED).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.findById(booking.getId())).thenReturn(Optional.of(booking));
        assertThrows(AppException.class, () -> service.cancellationQuote(booking.getId(), "customer@test.com"));
        verifyNoInteractions(payments, pricing);
    }
}
