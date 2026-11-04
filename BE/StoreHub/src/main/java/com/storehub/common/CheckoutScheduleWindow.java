package com.storehub.common;

import com.storehub.entity.Booking;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

public record CheckoutScheduleWindow(LocalDate earliest, LocalDate latest) {
    public static CheckoutScheduleWindow forBooking(Booking booking, LocalDate today) {
        LocalDate end = booking.getEndDate();
        if (end == null) throw new IllegalArgumentException("Booking end date is required");
        if (end.isBefore(today)) return new CheckoutScheduleWindow(today, today.plusDays(1));
        long remaining = ChronoUnit.DAYS.between(today, end);
        long notice = Math.max(0, booking.getReturnNoticeDays() == null ? 0 : booking.getReturnNoticeDays());
        return new CheckoutScheduleWindow(today.plusDays(Math.min(notice, remaining)), end);
    }
    public boolean contains(LocalDate date) {
        return !date.isBefore(earliest) && !date.isAfter(latest);
    }
}
