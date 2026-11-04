package com.storehub.service;

import com.storehub.dto.response.ReturnSettlementResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.HandoverRecord;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.*;
import static org.junit.jupiter.api.Assertions.*;

class ReturnSettlementQuoteTest {
    Booking booking() {
        return Booking.builder().endDate(LocalDate.of(2026,11,1))
                .overdueGraceDays(1).overdueDailyLateFee(new BigDecimal("50000"))
                .depositPaid(new BigDecimal("500000")).build();
    }
    @Test void threeDaysLateMinusGraceShowsCorrectNetDeposit() {
        var quote = ReturnSettlementResponse.calculate(booking(), LocalDateTime.of(2026,11,4,15,0),
                BigDecimal.ZERO, BigDecimal.ZERO, null);
        assertEquals(3,quote.overdueDays()); assertEquals(2,quote.chargeableDays());
        assertEquals(new BigDecimal("100000"),quote.totalLateFee());
        assertEquals(new BigDecimal("100000"),quote.lateFeeDeduction());
        assertEquals(new BigDecimal("400000"),quote.depositRefund());
        assertEquals(BigDecimal.ZERO,quote.additionalPayment());
    }
    @Test void onExpiryOrWithinGraceDoesNotDeductDeposit() {
        for(int day : new int[]{1,2}) {
            var q=ReturnSettlementResponse.calculate(booking(),LocalDateTime.of(2026,11,day,20,0),
                    BigDecimal.ZERO,BigDecimal.ZERO,null);
            assertEquals(0,q.totalLateFee().signum());
            assertEquals(new BigDecimal("500000"),q.depositRefund());
        }
    }
    @Test void prepaidFeesAreNotDeductedAgain() {
        var q=ReturnSettlementResponse.calculate(booking(),LocalDateTime.of(2026,11,4,15,0),
                new BigDecimal("50000"),BigDecimal.ZERO,null);
        assertEquals(new BigDecimal("50000"),q.lateFeeDeduction());
        assertEquals(new BigDecimal("450000"),q.depositRefund());
    }
    @Test void insufficientDepositShowsOnlyRemainingExcess() {
        var b=booking(); b.setDepositPaid(new BigDecimal("50000"));
        var q=ReturnSettlementResponse.calculate(b,LocalDateTime.of(2026,11,4,15,0),
                BigDecimal.ZERO,BigDecimal.ZERO,null);
        assertEquals(0,q.depositRefund().signum());
        assertEquals(new BigDecimal("50000"),q.additionalPayment());
    }
    @Test void finalizedSnapshotSurvivesLaterRefundAndTimePassing() {
        var b=booking(); b.setReturnTime(LocalDateTime.of(2026,11,4,15,0)); b.setDepositPaid(BigDecimal.ZERO);
        var record=HandoverRecord.builder().depositBeforeReturn(new BigDecimal("500000"))
                .lateFeeDeduction(new BigDecimal("100000")).depositRefundAmount(new BigDecimal("400000"))
                .damageFee(BigDecimal.ZERO).additionalPaymentAmount(BigDecimal.ZERO).build();
        var q=ReturnSettlementResponse.calculate(b,LocalDateTime.of(2027,11,4,15,0),
                BigDecimal.ZERO,BigDecimal.ZERO,record);
        assertTrue(q.finalized()); assertEquals(3,q.overdueDays());
        assertEquals(new BigDecimal("500000"),q.depositBefore());
        assertEquals(new BigDecimal("400000"),q.depositRefund());
    }
    @Test void historicalCompletedRefundKeepsItsOriginalAmountsAfterHeldBalanceBecomesZero() {
        var b=booking(); b.setReturnTime(LocalDateTime.of(2026,11,4,15,0)); b.setDepositPaid(BigDecimal.ZERO);
        var q=ReturnSettlementResponse.calculate(b,LocalDateTime.of(2027,11,4,15,0),
                BigDecimal.ZERO,BigDecimal.ZERO,null);
        q=q.withHistoricalRefund(com.storehub.entity.RefundRequest.builder()
                .originalPayment(com.storehub.entity.Payment.builder().amount(new BigDecimal("500000")).build())
                .depositAmount(new BigDecimal("400000")).damageDeduction(new BigDecimal("100000")).build());
        assertEquals(new BigDecimal("500000"),q.depositBefore());
        assertEquals(new BigDecimal("400000"),q.depositRefund());
        assertEquals(new BigDecimal("100000"),q.damageDeduction());
    }
}
