package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.enums.BookingStatus;
import com.storehub.mapper.CustomerStorageMapper;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class MyRentedUnitsStatusTest {
    @Test
    void exposesOfficialFacilityContactAndAssignedManagerName() {
        User manager = new User(); manager.setFullName("Nguyễn Văn Quản Lý");
        var facility = com.storehub.entity.Facility.builder().name("StoreHub")
                .manager(manager).contactPhone("0901234567").email("facility@storehub.test").build();
        Booking booking = Booking.builder().storageUnit(com.storehub.entity.StorageUnit.builder()
                .facility(facility).build()).build();
        var realMapper = org.mapstruct.factory.Mappers.getMapper(CustomerStorageMapper.class);
        var response = realMapper.toMyUnitResponse(booking);
        assertEquals("Nguyễn Văn Quản Lý", response.getFacilityManagerName());
        assertEquals("0901234567", response.getFacilityContactPhone());
        assertEquals("facility@storehub.test", response.getFacilityContactEmail());
    }
    @Mock com.storehub.repository.RefundRequestRepository refunds;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock PaymentRepository payments;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService paymentService;
    @Mock CustomerStorageMapper mapper;
    @Mock PasswordEncoder encoder;
    @InjectMocks CustomerStorageServiceImpl storage;

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.CsvSource({
            "ACTIVE,-2,true,2", "ACTIVE,-1,true,1", "ACTIVE,0,false,0", "ACTIVE,1,false,0",
            "CONFIRMED,-2,false,0", "COMPLETED,-2,false,0", "CANCELLED,-2,false,0"
    })
    void expiryComesFromVietnamCalendarRatherThanSchedulerMarker(BookingStatus status, int offset, boolean expired, long days) {
        Booking booking = Booking.builder().status(status)
                .endDate(java.time.LocalDate.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).plusDays(offset))
                .overdueDetectedAt(offset >= 0 ? java.time.LocalDateTime.now().minusDays(2) : null).build();
        when(mapper.toMyUnitResponse(booking)).thenReturn(MyUnitResponse.builder().build());
        MyUnitResponse response = org.springframework.test.util.ReflectionTestUtils.invokeMethod(storage, "mapToResponse", booking);
        assertEquals(expired, response.isOverdue());
        assertEquals(days, response.getOverdueDays());
    }

    @Test
    void rentedUnitsAndAwaitingHandoverUseSeparateStatuses() {
        UUID customerId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.ACTIVE)))
                .thenReturn(List.of(new Booking()));
        Booking awaiting = Booking.builder().status(BookingStatus.CONFIRMED).build();
        Booking cancelled = Booking.builder().status(BookingStatus.CANCELLED).build();
        when(bookings.findAwaitingOrCancelledPaidBookingsByCustomerId(customerId))
                .thenReturn(List.of(awaiting, cancelled));
        when(mapper.toMyUnitResponse(any(Booking.class)))
                .thenReturn(MyUnitResponse.builder().build());

        assertEquals(1, storage.getMyRentedUnits("customer@test.com").size());
        assertEquals(2, storage.getAwaitingHandover("customer@test.com").size());
        verify(bookings).findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.ACTIVE));
        verify(bookings).findAwaitingOrCancelledPaidBookingsByCustomerId(customerId);
    }
    @Test
    void cancelledBookingIsRefundedOnlyAfterEveryRefundIsCompleted() {
        UUID customerId = UUID.randomUUID(), bookingId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        Booking booking = Booking.builder().status(BookingStatus.CANCELLED).build(); booking.setId(bookingId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.findAwaitingOrCancelledPaidBookingsByCustomerId(customerId)).thenReturn(List.of(booking));
        when(mapper.toMyUnitResponse(booking)).thenAnswer(inv -> MyUnitResponse.builder().build());
        when(refunds.existsByBooking_IdAndStatus(bookingId, com.storehub.enums.RefundStatus.COMPLETED)).thenReturn(true);
        when(refunds.existsByBooking_IdAndStatusNot(bookingId, com.storehub.enums.RefundStatus.COMPLETED)).thenReturn(true, false);
        org.junit.jupiter.api.Assertions.assertFalse(storage.getAwaitingHandover("customer@test.com").get(0).isRefundCompleted());
        org.junit.jupiter.api.Assertions.assertTrue(storage.getAwaitingHandover("customer@test.com").isEmpty());
    }

}
