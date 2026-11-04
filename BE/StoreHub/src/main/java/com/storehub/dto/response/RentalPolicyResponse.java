package com.storehub.dto.response;

import com.storehub.entity.Booking;
import java.math.BigDecimal;

public record RentalPolicyResponse(BigDecimal dailyLateFee, Integer overdueGraceDays,
        Integer overdueAccessDisableDays, Integer overdueSealingDays, Integer returnNoticeDays,
        Integer refundSlaDays, boolean legacy) {
    public static RentalPolicyResponse from(Booking booking) {
        return new RentalPolicyResponse(booking.getOverdueDailyLateFee(), booking.getOverdueGraceDays(),
                booking.getOverdueAccessDisableDays(), booking.getOverdueSealingDays(),
                booking.getReturnNoticeDays(), booking.getRefundSlaDays(),
                Boolean.TRUE.equals(booking.getRefundPolicyLegacy()) || Boolean.TRUE.equals(booking.getOverduePolicyLegacy()));
    }
}
