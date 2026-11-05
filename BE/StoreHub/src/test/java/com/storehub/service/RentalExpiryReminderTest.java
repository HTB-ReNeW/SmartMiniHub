package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.NotificationType;
import com.storehub.repository.*;
import com.storehub.scheduler.OverdueScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RentalExpiryReminderTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock ActivityLogService logs;
    @Mock NotificationService notifications;
    @Mock NotificationRepository notificationRepository;
    @InjectMocks OverdueScheduler scheduler;
    private Booking booking;
    private final LocalDate today = LocalDate.of(2026, 11, 4);

    @BeforeEach
    void setup() {
        User customer = new User(); customer.setId(UUID.randomUUID());
        Facility facility = Facility.builder().name("StoreHub").build(); facility.setId(UUID.randomUUID());
        booking = Booking.builder().bookingCode("BK-EXPIRY").customer(customer).status(BookingStatus.ACTIVE)
                .storageUnit(StorageUnit.builder().unitCode("S-101").facility(facility).build())
                .endDate(today.minusDays(1)).overdueDailyLateFee(BigDecimal.valueOf(50000))
                .overdueGraceDays(1).overdueAccessDisableDays(3).overdueSealingDays(7).build();
        booking.setId(UUID.randomUUID());
    }

    private void process(LocalDate day) {
        ReflectionTestUtils.invokeMethod(scheduler, "processOneBooking", booking, day, day.atTime(11, 10));
    }

    @Test
    void firstExpiredDayNotifiesOnceEvenBeforeAnyFeeOrProcessingMarker() {
        Set<String> savedTitles = new HashSet<>();
        when(notificationRepository.existsByRecipient_IdAndReferenceIdAndTitle(any(), any(), anyString()))
                .thenAnswer(call -> savedTitles.contains(call.getArgument(2)));
        doAnswer(call -> { savedTitles.add(call.getArgument(1)); return null; })
                .when(notifications).notifyUser(any(), anyString(), anyString(), any(), any(), anyString(), any());
        process(today);
        process(today);
        verify(notifications, times(1)).notifyUser(eq(booking.getCustomer()), anyString(),
                contains("gia hạn thuê hoặc gửi yêu cầu trả kho"), eq(NotificationType.SYSTEM), eq(booking.getId()),
                eq("BOOKING"), eq(booking.getStorageUnit().getFacility()));
        assertNull(booking.getOverdueDetectedAt());
        verifyNoInteractions(payments);
    }

    @Test
    void previouslyProcessedBookingsReceiveTheMissingReminder() {
        booking.setOverdueDetectedAt(today.minusDays(1).atStartOfDay());
        process(today);
        verify(notifications).notifyUser(any(), anyString(), anyString(), any(), eq(booking.getId()), eq("BOOKING"), any());
    }

    @Test
    void existingReminderDoesNotRepeatAfterBeingReadOrOnLaterDays() {
        when(notificationRepository.existsByRecipient_IdAndReferenceIdAndTitle(any(), any(), anyString())).thenReturn(true);
        booking.setOverdueGraceDays(3);
        process(today);
        process(today.plusDays(1));
        verifyNoInteractions(notifications);
    }

    @Test
    void aNewExpiryAfterRenewalCanNotifyAgain() {
        ArgumentCaptor<String> titles = ArgumentCaptor.forClass(String.class);
        process(today);
        booking.setEndDate(booking.getEndDate().plusMonths(1));
        process(booking.getEndDate().plusDays(1));
        verify(notifications, times(2)).notifyUser(any(), titles.capture(), anyString(), any(), any(), anyString(), any());
        assertNotEquals(titles.getAllValues().get(0), titles.getAllValues().get(1));
    }

    @Test
    void expiryTodayNotifiesWithoutChargingAndFutureDoesNotNotify() {
        booking.setEndDate(today);
        process(today);
        verify(notifications).notifyUser(any(), anyString(), anyString(), any(), any(), anyString(), any());
        clearInvocations(notifications, notificationRepository);
        booking.setEndDate(today.plusDays(30));
        process(today);
        verifyNoInteractions(notifications, notificationRepository, payments);
    }

    @Test
    void scheduledReturnsAreAcknowledgedInsteadOfAskingForAnotherRequest() {
        booking.setScheduledReturnTime(today.plusDays(1).atTime(10, 0));
        process(today);
        verify(notifications).notifyUser(any(), anyString(), contains("Bạn đã có lịch trả kho"), any(), any(), anyString(), any());
    }
}
