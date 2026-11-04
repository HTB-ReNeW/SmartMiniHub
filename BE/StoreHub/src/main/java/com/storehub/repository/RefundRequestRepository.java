package com.storehub.repository;

import com.storehub.entity.RefundRequest;
import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.enums.RefundStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.time.LocalDateTime;
import java.math.BigDecimal;

public interface RefundRequestRepository extends JpaRepository<RefundRequest, UUID> {
    long countByBooking_StorageUnit_Facility_Id(UUID facilityId);
    long countByBooking_StorageUnit_Facility_IdAndStatus(UUID facilityId, RefundStatus status);
    @Query(value = """
            select r from RefundRequest r where r.booking.storageUnit.facility.id = :facilityId
            and (:filter = 'ALL' or (:filter = 'COMPLETED' and r.status = :completed)
                 or (:filter = 'PENDING' and r.status <> :completed))
            order by r.createdAt desc, r.id desc
            """, countQuery = """
            select count(r) from RefundRequest r where r.booking.storageUnit.facility.id = :facilityId
            and (:filter = 'ALL' or (:filter = 'COMPLETED' and r.status = :completed)
                 or (:filter = 'PENDING' and r.status <> :completed))
            """)
    Page<RefundRequest> findFilteredForManager(@Param("facilityId") UUID facilityId,
            @Param("completed") RefundStatus completed, @Param("filter") String filter, Pageable pageable);
    Optional<RefundRequest> findFirstByBooking_IdAndOriginalPayment_PaymentTypeOrderByCreatedAtDesc(
            UUID bookingId, com.storehub.enums.PaymentType paymentType);
    @Query("select r.id from RefundRequest r where r.status <> com.storehub.enums.RefundStatus.COMPLETED "
            + "and r.dueAt <= :now order by r.dueAt, r.id")
    Page<UUID> findDueReminderIds(@Param("now") LocalDateTime now, Pageable pageable);

    boolean existsByBooking_Id(UUID bookingId);
    boolean existsByBooking_IdAndStatus(UUID bookingId, RefundStatus status);
    boolean existsByBooking_IdAndStatusNot(UUID bookingId, RefundStatus status);
    boolean existsByOriginalPayment_Id(UUID paymentId);
    boolean existsByIdAndBooking_StorageUnit_Facility_Id(UUID id, UUID facilityId);
    Optional<RefundRequest> findByRefundPayment_Id(UUID refundPaymentId);
    Optional<RefundRequest> findByOriginalPayment_Id(UUID originalPaymentId);
    @Query(value = """
            SELECT r FROM RefundRequest r
            WHERE r.booking.storageUnit.facility.id = :facilityId
            ORDER BY CASE WHEN r.status = :completed THEN 1 ELSE 0 END,
                     CASE WHEN r.dueAt < :now AND r.status <> :completed THEN 0 ELSE 1 END,
                     CASE WHEN r.status <> :completed THEN r.dueAt END ASC,
                     CASE WHEN r.status = :completed THEN r.createdAt END DESC,
                     r.id ASC
            """, countQuery = """
            SELECT COUNT(r) FROM RefundRequest r
            WHERE r.booking.storageUnit.facility.id = :facilityId
            """)
    Page<RefundRequest> findForManager(@Param("facilityId") UUID facilityId,
            @Param("completed") RefundStatus completed, @Param("now") LocalDateTime now,
            Pageable pageable);

    List<RefundRequest> findTop20ByStatusOrderByDueAtAsc(RefundStatus status);

    List<RefundRequest> findTop20ByStatusInAndUpdatedStatusAtBeforeOrderByUpdatedStatusAtAsc(
            List<RefundStatus> statuses, LocalDateTime before);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from RefundRequest r where r.id = :id")
    Optional<RefundRequest> lockById(@Param("id") UUID id);

    @Query("""
            SELECT new com.storehub.dto.response.FacilityRevenueResponse(
                f.id, f.name,
                COALESCE(SUM(r.rentalAmount), 0),
                COALESCE(SUM(r.depositAmount), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.DEPOSIT
                    THEN r.rentalAmount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE
                    THEN r.rentalAmount ELSE null END), 0),
                0L)
            FROM RefundRequest r
            JOIN r.booking b JOIN b.storageUnit su JOIN su.facility f
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            GROUP BY f.id, f.name
            """)
    List<FacilityRevenueResponse> sumCompletedRefundsByFacility(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT new com.storehub.dto.response.SystemRevenueSummaryResponse(
                COALESCE(SUM(r.rentalAmount), 0),
                COALESCE(SUM(r.depositAmount), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.DEPOSIT
                    THEN r.rentalAmount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE
                    THEN r.rentalAmount ELSE null END), 0),
                0L)
            FROM RefundRequest r
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            """)
    SystemRevenueSummaryResponse sumCompletedRefundsSystem(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT COALESCE(SUM(r.rentalAmount), 0)
            FROM RefundRequest r
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND (charge.note = 'OVERDUE_LATE_FEE'
                 OR charge.note = 'Phí phạt quá hạn')
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            """)
    BigDecimal sumCompletedOverdueRefunds(@Param("fromDate") LocalDateTime fromDate,
                                          @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT COALESCE(SUM(r.rentalAmount), 0)
            FROM RefundRequest r
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.booking.storageUnit.facility.id = :facilityId
            """)
    BigDecimal sumCompletedRentalRefundsByFacility(@Param("facilityId") UUID facilityId);
}
