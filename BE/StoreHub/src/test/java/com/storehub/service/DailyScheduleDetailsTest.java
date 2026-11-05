package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DailyScheduleDetailsTest {
    @Mock BookingRepository bookings;
    @Mock FacilityAccess access;
    @InjectMocks FacilityOperationsServiceImpl service;

    @Test
    void scheduleIncludesCustomerContactUnitDimensionsAndSavedReturnNotes() {
        LocalDate day = LocalDate.now();
        Facility facility = Facility.builder().name("StoreHub").build(); facility.setId(UUID.randomUUID());
        User customer = User.builder().fullName("Nguyen Van An").email("customer@test.com").phone("0901234567").build();
        customer.setId(UUID.randomUUID());
        StorageUnit unit = StorageUnit.builder().facility(facility).unitCode("S-101").floorLevel("Tang 2")
                .unitType(UnitType.builder().typeName("Small").dimensions("1m x 1m x 2m").build()).build();
        Booking booking = Booking.builder().bookingCode("BK-RETURN").customer(customer).storageUnit(unit)
                .status(BookingStatus.ACTIVE).startDate(day.minusMonths(1)).endDate(day)
                .scheduledReturnTime(day.atTime(10, 0)).checkoutNotes("Goi truoc 15 phut").build();
        booking.setId(UUID.randomUUID());
        when(access.require("manager@test.com", facility.getId())).thenReturn(new User());
        when(bookings.findCheckInSchedule(any(), any(), any())).thenReturn(List.of());
        when(bookings.findCheckOutSchedule(any(), any(), any(), any())).thenReturn(List.of(booking));
        var result = service.getDailySchedule(facility.getId(), day, "manager@test.com");
        assertEquals(1, result.size());
        var item = result.get(0);
        assertEquals("0901234567", item.getCustomerPhone());
        assertEquals("customer@test.com", item.getCustomerEmail());
        assertEquals("1m x 1m x 2m", item.getDimensions());
        assertEquals("Tang 2", item.getFloorLevel());
        assertEquals(day.minusMonths(1), item.getStartDate());
        assertEquals(day, item.getEndDate());
        assertEquals("Goi truoc 15 phut", item.getNotes());
    }
}
