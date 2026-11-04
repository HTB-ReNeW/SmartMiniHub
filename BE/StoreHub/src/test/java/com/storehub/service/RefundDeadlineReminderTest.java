package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.NotificationRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.scheduler.RefundReminderScheduler;
import com.storehub.service.impl.RefundReminderService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

@ExtendWith(MockitoExtension.class)
class RefundDeadlineReminderTest {
    @Mock RefundRequestRepository refunds;
    @Mock NotificationRepository notifications;
    @Mock NotificationService delivery;
    @Mock com.storehub.repository.UserRepository users;
    @InjectMocks RefundReminderService reminders;
    final LocalDateTime now = LocalDateTime.of(2026, 11, 4, 9, 0);

    RefundRequest request(RefundStatus status, LocalDateTime due) {
        User customer = new User(); customer.setId(UUID.randomUUID());
        User manager = new User(); manager.setId(UUID.randomUUID());
        Facility facility = Facility.builder().name("StoreHub").manager(manager).build();
        Booking booking = Booking.builder().bookingCode("BK-TEST").customer(customer)
                .storageUnit(StorageUnit.builder().facility(facility).build()).build();
        RefundRequest r = RefundRequest.builder().booking(booking).status(status)
                .dueAt(due).amount(new BigDecimal("3050000")).build();
        r.setId(UUID.randomUUID());
        when(refunds.lockById(r.getId())).thenReturn(Optional.of(r));
        return r;
    }

    @Test
    void notifiesCustomerAndManagerAtExactDeadline() {
        var r = request(RefundStatus.AWAITING_BANK_TRANSFER, now);
        reminders.remind(r.getId(), now);
        verify(delivery).notifyUser(eq(r.getBooking().getCustomer()), anyString(),
                contains("3.050.000 đ"), eq(NotificationType.SYSTEM), eq(r.getId()),
                eq("REFUND_REQUEST"), any());
        verify(delivery).notifyUser(eq(r.getBooking().getStorageUnit().getFacility().getManager()),
                anyString(), contains("BK-TEST"), eq(NotificationType.SYSTEM), eq(r.getId()),
                eq("REFUND_REQUEST"), any());
        verifyNoMoreInteractions(delivery);
    }

    @Test
    void doesNotRepeatDeliveredRemindersEvenAfterRead() {
        var r = request(RefundStatus.NEEDS_REVIEW, now.minusDays(2));
        when(notifications.existsByRecipient_IdAndReferenceIdAndTitle(any(), eq(r.getId()), anyString()))
                .thenReturn(true);
        reminders.remind(r.getId(), now);
        verifyNoInteractions(delivery);
    }

    @Test
    void retriesOnlyMissingRecipientNotification() {
        var r = request(RefundStatus.REJECTED, now.minusDays(1));
        when(notifications.existsByRecipient_IdAndReferenceIdAndTitle(
                eq(r.getBooking().getCustomer().getId()), eq(r.getId()), anyString())).thenReturn(true);
        reminders.remind(r.getId(), now);
        verify(delivery, times(1)).notifyUser(
                eq(r.getBooking().getStorageUnit().getFacility().getManager()), anyString(), anyString(),
                eq(NotificationType.SYSTEM), eq(r.getId()), eq("REFUND_REQUEST"), any());
    }

    @Test
    void neverRemindsCompletedOrNotYetDueRequests() {
        var completed = request(RefundStatus.COMPLETED, now.minusDays(1));
        reminders.remind(completed.getId(), now);
        var future = request(RefundStatus.AWAITING_BANK_TRANSFER, now.plusMinutes(1));
        reminders.remind(future.getId(), now);
        verifyNoInteractions(delivery, notifications);
    }

    @Test
    void schedulerProcessesMoreThanOnePageDespiteAnIndividualFailure() {
        RefundReminderService worker = mock(RefundReminderService.class);
        var ids = java.util.stream.IntStream.range(0, 12).mapToObj(i -> UUID.randomUUID()).toList();
        when(refunds.findDueReminderIds(any(), eq(PageRequest.of(0,10))))
                .thenReturn(new PageImpl<>(ids.subList(0,10), PageRequest.of(0,10),12));
        when(refunds.findDueReminderIds(any(), eq(PageRequest.of(1,10))))
                .thenReturn(new PageImpl<>(ids.subList(10,12), PageRequest.of(1,10),12));
        doThrow(new IllegalStateException("retry later")).when(worker).remind(eq(ids.get(0)),any());
        new RefundReminderScheduler(refunds, worker).remindDueRefunds();
        for (var id : ids) verify(worker).remind(eq(id), any());
    }
}
