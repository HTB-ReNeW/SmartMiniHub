package com.storehub.entity;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "deposit_deductions", uniqueConstraints = @UniqueConstraint(
        name = "uq_deposit_deduction_source_type", columnNames = {"original_payment_id", "deduction_type"}))
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class DepositDeduction extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "booking_id", nullable = false, updatable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "original_payment_id", nullable = false, updatable = false)
    private Payment originalPayment;

    @Column(nullable = false, precision = 12, scale = 2, updatable = false)
    private BigDecimal amount;

    // DAMAGE, CANCELLATION or LATE_FEE: held deposit converted to revenue, never a new cash receipt.
    @Column(name = "deduction_type", nullable = false, length = 20, updatable = false)
    private String deductionType;

    @Column(columnDefinition = "TEXT", nullable = false, updatable = false)
    private String reason;

    @Column(name = "recorded_at", nullable = false, updatable = false)
    private LocalDateTime recordedAt;
}
