package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.exception.AppException;
import com.storehub.repository.*;
import com.storehub.service.impl.PricingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class CancellationPolicySnapshotTest {
    @Mock FacilityPolicyService policies;
    @Mock UnitTypeRepository types;
    @Mock StorageUnitRepository units;
    @Mock FacilityPolicyRepository policyRepository;
    @Mock FacilityRepository facilities;
    @InjectMocks PricingServiceImpl pricing;

    @Test
    void refundUsesBookedRulesAtAllBoundariesWithoutReadingCurrentPolicy() {
        Booking booking = Booking.builder().cancellationFullRefundHours(48)
                .cancellationPartialRefundHours(24).cancellationPartialRefundPercent(50.0).build();
        LocalDateTime start = LocalDateTime.of(2027, 1, 10, 18, 0);
        BigDecimal paid = new BigDecimal("1000");
        assertEquals(paid, pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(48)));
        assertEquals(new BigDecimal("500"), pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(24)));
        assertEquals(BigDecimal.ZERO, pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(24).plusSeconds(1)));
        assertEquals(BigDecimal.ZERO, pricing.calculateCancellationRefund(booking, paid, start, start.plusHours(1)));
        verifyNoInteractions(policyRepository, policies);
    }

    @Test
    void missingSnapshotCannotSilentlyUseTodaysPolicy() {
        LocalDateTime start = LocalDateTime.of(2027, 1, 10, 18, 0);
        assertThrows(AppException.class, () -> pricing.calculateCancellationRefund(
                new Booking(), BigDecimal.TEN, start, start.minusDays(3)));
        verifyNoInteractions(policyRepository);
    }
    @Test
    void usesExactElapsed24HoursAndStoredPercentages() {
        Booking booking = Booking.builder().cancellationWithin24hPercent(100.0)
                .cancellationAfter24hPercent(50.0).build();
        LocalDateTime placed = LocalDateTime.of(2026, 11, 3, 14, 30);
        booking.setCreatedAt(placed);
        BigDecimal deposit = new BigDecimal("500000");
        LocalDateTime irrelevantStart = placed.plusDays(10);
        assertEquals(new BigDecimal("500000"), pricing.calculateCancellationRefund(booking, deposit, irrelevantStart, placed.plusHours(24).minusNanos(1)));
        assertEquals(new BigDecimal("500000"), pricing.calculateCancellationRefund(booking, deposit, irrelevantStart, placed.plusHours(24)));
        assertEquals(new BigDecimal("250000"), pricing.calculateCancellationRefund(booking, deposit, irrelevantStart, placed.plusHours(24).plusNanos(1)));
        assertEquals(new BigDecimal("250000"), pricing.calculateCancellationRefund(booking, deposit, placed.minusDays(1), placed.plusDays(3)));
        booking.setCancellationWithin24hPercent(80.0);
        booking.setCancellationAfter24hPercent(30.0);
        assertEquals(new BigDecimal("400000"), pricing.calculateCancellationRefund(booking, deposit, irrelevantStart, placed));
        assertEquals(new BigDecimal("150000"), pricing.calculateCancellationRefund(booking, deposit, irrelevantStart, placed.plusDays(2)));
        verifyNoInteractions(policyRepository, policies);
    }

}
