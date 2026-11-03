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
}
