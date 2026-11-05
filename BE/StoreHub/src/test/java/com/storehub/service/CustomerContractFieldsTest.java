package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.mapper.CustomerStorageMapper;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import java.math.BigDecimal;
import static org.junit.jupiter.api.Assertions.*;

class CustomerContractFieldsTest {
    @Test
    void contractIncludesCustomerAndBookedServiceFeeEvenBeforeUnitAssignment() {
        Booking booking = Booking.builder().customer(User.builder().fullName("Nguyen Van An").build())
            .quotedManagementFee(new BigDecimal("150000")).build();
        var result = Mappers.getMapper(CustomerStorageMapper.class).toMyUnitResponse(booking);
        assertEquals("Nguyen Van An", result.getCustomerName());
        assertEquals(new BigDecimal("150000"), result.getServiceFee());
    }

    @Test
    void contractAndCheckoutDetailsUseTheSavedBookingValues() {
        var time = java.time.LocalDateTime.of(2026, 11, 5, 10, 0);
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("70000"))
                .overdueGraceDays(2).overdueAccessDisableDays(4).overdueSealingDays(8)
                .refundSlaDays(3).returnNoticeDays(1).scheduledReturnTime(time)
                .refundBankCode("VCB").refundAccountNumber("0012345678")
                .refundAccountName("NGUYEN VAN AN").checkoutNotes("Goi truoc 15 phut").build();
        var result = Mappers.getMapper(CustomerStorageMapper.class).toMyUnitResponse(booking);
        assertEquals("0012345678", result.getRefundAccountNumber());
        assertEquals("VCB", result.getRefundBankCode());
        assertEquals("NGUYEN VAN AN", result.getRefundAccountName());
        assertEquals(time, result.getScheduledReturnTime());
        assertEquals("Goi truoc 15 phut", result.getCheckoutNotes());
        assertEquals(3, result.getRentalPolicy().refundSlaDays());
        assertEquals(new BigDecimal("70000"), result.getRentalPolicy().dailyLateFee());
    }
}
