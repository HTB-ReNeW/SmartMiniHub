package com.storehub.dto.response;

import com.storehub.entity.Booking;
import com.storehub.entity.HandoverRecord;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

public record ReturnSettlementResponse(LocalDate endDate, LocalDateTime returnAt, long overdueDays,
        Integer graceDays, long chargeableDays, BigDecimal dailyLateFee, BigDecimal totalLateFee,
        BigDecimal lateFeeAlreadyPaid, BigDecimal depositBefore, BigDecimal lateFeeDeduction,
        BigDecimal damageDeduction, BigDecimal depositRefund, BigDecimal additionalPayment, boolean finalized) {
    private static BigDecimal value(BigDecimal amount) { return amount == null ? BigDecimal.ZERO : amount; }

    public static ReturnSettlementResponse calculate(Booking booking, LocalDateTime now, BigDecimal paid,
            BigDecimal outstanding, HandoverRecord record) {
        LocalDateTime returnAt = booking.getReturnTime() == null ? now : booking.getReturnTime();
        long days = Math.max(0, ChronoUnit.DAYS.between(booking.getEndDate(), returnAt.toLocalDate()));
        long charged = Math.max(0, days - (booking.getOverdueGraceDays() == null ? 0 : booking.getOverdueGraceDays()));
        BigDecimal total = booking.getOverdueDailyLateFee() == null ? value(outstanding).add(value(paid))
                : booking.getOverdueDailyLateFee().multiply(BigDecimal.valueOf(charged));
        BigDecimal owed = total.subtract(value(paid)).max(BigDecimal.ZERO);
        BigDecimal deposit = value(booking.getDepositPaid());
        BigDecimal damage = record == null ? BigDecimal.ZERO : value(record.getDamageFee());
        BigDecimal deduction = owed.min(deposit.subtract(damage).max(BigDecimal.ZERO));
        BigDecimal refund = deposit.subtract(damage).subtract(deduction).max(BigDecimal.ZERO);
        BigDecimal additional = owed.subtract(deduction).max(BigDecimal.ZERO);
        boolean finalized = booking.getReturnTime() != null;
        if (record != null && record.getDepositBeforeReturn() != null) {
            deposit = record.getDepositBeforeReturn();
            deduction = value(record.getLateFeeDeduction());
            refund = value(record.getDepositRefundAmount());
            additional = value(outstanding);
        } else if (finalized) {
            // Legacy inspections have no new settlement snapshot: never claim a deduction that was not recorded.
            deduction = value(booking.getReturnLateFeeDeduction());
            additional = value(outstanding);
            refund = deposit.subtract(damage).max(BigDecimal.ZERO);
        }
        return new ReturnSettlementResponse(booking.getEndDate(), returnAt, days, booking.getOverdueGraceDays(),
                charged, booking.getOverdueDailyLateFee(), total, value(paid), deposit, deduction,
                damage, refund, additional, finalized);
    }

    public ReturnSettlementResponse withHistoricalRefund(com.storehub.entity.RefundRequest refund) {
        BigDecimal source = refund.getOriginalPayment() == null ? depositBefore
                : value(refund.getOriginalPayment().getAmount());
        return new ReturnSettlementResponse(endDate, returnAt, overdueDays, graceDays, chargeableDays,
                dailyLateFee, totalLateFee, lateFeeAlreadyPaid, source, lateFeeDeduction,
                value(refund.getDamageDeduction()), value(refund.getDepositAmount()), additionalPayment, finalized);
    }
}
