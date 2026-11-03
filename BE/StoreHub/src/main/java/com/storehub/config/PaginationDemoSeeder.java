package com.storehub.config;

import com.storehub.common.TermsSnapshot;
import com.storehub.entity.*;
import com.storehub.enums.*;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/** Additive development fixtures. Called inside SeedConfig's transaction, including on existing databases. */
@Component
@ConditionalOnProperty(name = "seed.users.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
@Slf4j
public class PaginationDemoSeeder {
    static final int PAGE_DEMO_COUNT = 20;
    static final String PREFIX = "DEMO-PG-";
    private static final String WAREHOUSE =
            "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&q=80";
    private final EntityManager em;
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    @Value("${seed.pagination.enabled:true}") private boolean enabled = true;
    @Value("${seed.customer-password}") private String customerPassword;
    @Value("${seed.staff-password}") private String staffPassword;
    @Value("${seed.facility-manager-password}") private String managerPassword;
    @Value("${seed.demo-base-url:http://10.0.2.2:8080}") private String demoBaseUrl;

    private final List<Stamp> timestamps = new ArrayList<>();
    private LocalDateTime now;
    private String pinHash;
    private String customerHash;
    private String staffHash;
    private String managerHash;

    public void seed() {
        if (!enabled) return;
        User customer = find(User.class, "email", "customer@gmail.com");
        Facility primary = find(Facility.class, "code", "HCM-D1");
        if (customer == null || primary == null) {
            log.warn("Pagination demo skipped: default customer or HCM-D1 is missing");
            return;
        }
        now = LocalDateTime.now().withNano(0);
        timestamps.clear();
        // Encode once per role; fixture accounts use the same configured seed credentials.
        pinHash = encoder.encode("123456");
        customerHash = encoder.encode(customerPassword);
        staffHash = encoder.encode(staffPassword);
        managerHash = encoder.encode(managerPassword);
        List<UnitType> types = seedTypes();
        List<User> customers = new ArrayList<>();
        for (int i = 1; i <= PAGE_DEMO_COUNT; i++) {
            customers.add(account("customer", i, "CUSTOMER", customerHash, null));
            account("staff_free", i, "STAFF", staffHash, null);
            account("manager_free", i, "FACILITY_MANAGER", managerHash, null);
        }
        seedFacilities(types);
        for (String code : List.of("HCM-D1", "HCM-D7", "HCM-TD")) {
            Facility facility = find(Facility.class, "code", code);
            if (facility == null) continue;
            User staff = assignedStaff(facility);
            FacilityPolicy policy = policy(facility);
            for (int i = 1; i <= PAGE_DEMO_COUNT; i++) {
                account("staff_" + code.toLowerCase(Locale.ROOT), i, "STAFF", staffHash, facility);
                unit(facility, "FREE-" + number(i), types.get(i - 1), UnitStatus.AVAILABLE);
                for (BookingStatus status : BookingStatus.values()) {
                    // Only one deferred unpaid order per customer; other pending examples have separate owners.
                    User owner = status == BookingStatus.PENDING_PAYMENT && i > 1
                            ? customers.get(i - 1) : customer;
                    if (status == BookingStatus.PENDING_PAYMENT && !code.equals("HCM-D1")) continue;
                    seedBooking(facility, staff, owner, policy, types.get(i - 1), status, i);
                }
            }
            unit(facility, "MAINT-01", types.get(0), UnitStatus.UNDER_MAINTENANCE);
        }
        // Auditing timestamps otherwise replace fixture dates on INSERT. Only newly inserted demo rows are stamped.
        em.flush();
        Map<String, List<Object[]>> batches = new LinkedHashMap<>();
        for (Stamp stamp : timestamps) {
            batches.computeIfAbsent(stamp.table(), ignored -> new ArrayList<>())
                    .add(new Object[]{stamp.time(), stamp.time(), stamp.entity().getId()});
            stamp.entity().setCreatedAt(stamp.time());
            stamp.entity().setUpdatedAt(stamp.time());
        }
        batches.forEach((table, arguments) -> jdbc.batchUpdate(
                "update " + table + " set created_at = ?, updated_at = ? where id = ?", arguments));
        log.info("Pagination demo ready: {} new records; existing records were preserved", timestamps.size());
        timestamps.clear();
    }

    private List<UnitType> seedTypes() {
        List<UnitType> types = new ArrayList<>();
        for (int i = 1; i <= PAGE_DEMO_COUNT; i++) {
            String name = "Demo " + number(i) + " - " + (i <= 6 ? "Small" : i <= 13 ? "Medium" : "Large");
            UnitType type = find(UnitType.class, "typeName", name);
            if (type == null) {
                double width = 1 + ((i - 1) % 5) * 0.5;
                double length = 1 + ((i - 1) / 5) * 0.5;
                BigDecimal rent = BigDecimal.valueOf(400000 + i * 100000L);
                type = add(UnitType.builder().typeName(name)
                        .dimensions(String.format(Locale.ROOT, "%.1fm x %.1fm x 2.5m", length, width))
                        .areaSqm(length * width).basePricePerMonth(rent)
                        .depositAmount(rent.multiply(new BigDecimal("0.20"))).imageUrl(WAREHOUSE).build(),
                        "unit_types", now.minusDays(40).plusMinutes(i));
            }
            types.add(type);
        }
        return types;
    }

    private void seedFacilities(List<UnitType> types) {
        String[] areas = {"Thu Duc", "Binh Thanh", "Quan 7", "Tan Binh", "Go Vap"};
        for (int i = 1; i <= PAGE_DEMO_COUNT + 2; i++) {
            String code = PREFIX + number(i);
            Facility facility = find(Facility.class, "code", code);
            if (facility == null) {
                User manager = account("manager", i, "FACILITY_MANAGER", managerHash, null);
                facility = add(Facility.builder().code(code).name("StoreHub Demo " + number(i))
                        .address((100 + i) + " Nguyen Van Linh, " + areas[(i - 1) % areas.length])
                        .city("Ho Chi Minh City").email("pg.facility" + i + "@example.test")
                        .contactPhone(String.format("0283800%04d", i)).manager(manager)
                        .status(i == 21 ? FacilityStatus.INACTIVE : i == 22 ? FacilityStatus.MAINTENANCE : FacilityStatus.ACTIVE)
                        .description("Cơ sở demo phân trang " + number(i) + ": bảo vệ, camera và hệ thống PCCC đầy đủ.")
                        .airConditioned24h(i % 2 == 0).imageUrl(WAREHOUSE).images(List.of(WAREHOUSE)).build(),
                        "facilities", now.minusDays(30).plusHours(i));
                manager.setFacility(facility);
                manager.setAssignedAt(now.minusDays(29));
                manager.setAssignedBy(manager.getId());
            }
            policy(facility);
            // All 20 unit types actually exist at every demo facility; inactive facilities remain unavailable.
            for (int j = 0; j < types.size(); j++) {
                unit(facility, "FREE-" + number(j + 1), types.get(j),
                        i > 20 ? UnitStatus.UNDER_MAINTENANCE : UnitStatus.AVAILABLE);
            }
        }
    }

    private User account(String group, int i, String roleName, String hash, Facility facility) {
        String username = "pg_" + group + "_" + number(i);
        User user = find(User.class, "username", username);
        if (user != null) return user;
        Role role = find(Role.class, "name", roleName);
        if (role == null) throw new IllegalStateException("Missing seed role " + roleName);
        user = User.builder().username(username).email(username + "@example.test").password(hash)
                .fullName((roleName.equals("CUSTOMER") ? "Khach Demo " : roleName.equals("STAFF") ? "Nhan vien Demo " : "Quan ly Demo ") + number(i))
                .phone(String.format("09080%05d", Math.abs(username.hashCode() % 100000)))
                .avatar("https://i.pravatar.cc/150?u=" + username).role(role).facility(facility)
                .isActive(i != 20 || !group.equals("customer"))
                .assignedBy(facility == null || facility.getManager() == null ? null : facility.getManager().getId())
                .assignedAt(facility == null ? null : now.minusDays(25)).build();
        return add(user, "users", now.minusDays(28).plusMinutes(i));
    }

    private User assignedStaff(Facility facility) {
        return em.createQuery("select e from User e", User.class).getResultList().stream()
                .filter(u -> u.getRole() != null && "STAFF".equals(u.getRole().getName())
                        && u.getFacility() != null && u.getFacility().getId().equals(facility.getId())
                        && Boolean.TRUE.equals(u.getIsActive()))
                .sorted(Comparator.comparing(User::getUsername)).findFirst()
                .orElseGet(() -> account("staff_" + facility.getCode().toLowerCase(Locale.ROOT), 1, "STAFF", staffHash, facility));
    }

    private FacilityPolicy policy(Facility facility) {
        FacilityPolicy policy = em.createQuery("select e from FacilityPolicy e where e.facility = :value", FacilityPolicy.class)
                .setParameter("value", facility).getResultStream().findFirst().orElse(null);
        return policy != null ? policy : add(FacilityPolicy.builder().facility(facility)
                .depositPercentage(20.0).dailyLateFee(BigDecimal.valueOf(50000)).build(),
                "facility_policies", now.minusDays(29));
    }

    private StorageUnit unit(Facility facility, String suffix, UnitType type, UnitStatus status) {
        String code = "PG-" + suffix;
        StorageUnit unit = em.createQuery("select e from StorageUnit e where e.facility = :facility and e.unitCode = :code", StorageUnit.class)
                .setParameter("facility", facility).setParameter("code", code).getResultStream().findFirst().orElse(null);
        return unit != null ? unit : add(StorageUnit.builder().facility(facility).unitCode(code)
                .unitType(type).floorLevel("Tang " + (1 + Math.abs(suffix.hashCode() % 3))).status(status).build(),
                "storage_units", now.minusDays(24).plusMinutes(timestamps.size()));
    }

    private void seedBooking(Facility facility, User staff, User customer, FacilityPolicy policy,
                             UnitType type, BookingStatus status, int i) {
        String marker = switch (status) {
            case ACTIVE -> "A";
            case CONFIRMED -> "C";
            case COMPLETED -> "D";
            case CANCELLED -> "X";
            case PENDING_PAYMENT -> "P";
        };
        String code = PREFIX + facility.getCode().replace("HCM-", "") + "-" + marker + number(i);
        if (find(Booking.class, "bookingCode", code) != null) return;
        LocalDateTime placed = now.minusDays(3).minusMinutes(21 - i);
        LocalDateTime start = now.minusDays(5).withHour(10).withMinute(0);
        if (status == BookingStatus.CONFIRMED || status == BookingStatus.PENDING_PAYMENT || status == BookingStatus.CANCELLED)
            start = now.plusDays(2).withHour(10).withMinute(0);
        if (status == BookingStatus.CONFIRMED || status == BookingStatus.PENDING_PAYMENT)
            placed = now.minusMinutes(21 - i);
        if (status == BookingStatus.CONFIRMED) {
            start = now.toLocalDate().atTime(10 + (i - 1) % 10, 0);
            placed = start.minusDays(1).minusMinutes(i);
        }
        if (status == BookingStatus.CANCELLED) placed = i % 2 == 0 ? now.minusHours(2) : now.minusHours(30);
        if (status == BookingStatus.COMPLETED) {
            start = now.minusMonths(2).plusDays(i / 2).withHour(10).withMinute(0);
            placed = start.minusDays(1);
        }
        if (status == BookingStatus.ACTIVE) placed = start.minusDays(1).minusMinutes(i);
        int months = status == BookingStatus.COMPLETED ? 1 : 1 + (i - 1) % 3;
        if (status == BookingStatus.ACTIVE && i > 16) {
            int overdueDays = switch (i) { case 17 -> 1; case 18 -> 3; case 19 -> 7; default -> 8; };
            start = now.minusDays(overdueDays - 1L).minusMonths(months).withHour(10).withMinute(0);
            placed = start.minusDays(1);
        }
        BigDecimal rental = type.getBasePricePerMonth().multiply(BigDecimal.valueOf(months));
        BigDecimal deposit = type.getBasePricePerMonth().multiply(BigDecimal.valueOf(policy.getDepositPercentage() / 100));
        BigDecimal fee = policy.getManagementFeePerMonth().multiply(BigDecimal.valueOf(months));
        UnitStatus unitStatus = status == BookingStatus.ACTIVE ? UnitStatus.OCCUPIED
                : status == BookingStatus.CONFIRMED || status == BookingStatus.PENDING_PAYMENT ? UnitStatus.RESERVED : UnitStatus.AVAILABLE;
        StorageUnit unit = unit(facility, marker + number(i), type, unitStatus);
        Booking booking = Booking.builder().bookingCode(code).customer(customer).storageUnit(unit)
                .status(status).startDate(start.toLocalDate()).endDate(start.toLocalDate().plusMonths(months).minusDays(1))
                .scheduledCheckInTime(start).rentalMonths(months).totalRentalFee(rental)
                .quotedDepositAmount(deposit).quotedManagementFee(fee)
                .depositPaid(status == BookingStatus.PENDING_PAYMENT ? BigDecimal.ZERO : deposit)
                .unitAssignmentConfirmed(status != BookingStatus.PENDING_PAYMENT && (status != BookingStatus.CONFIRMED || i % 3 != 0))
                .paymentDeferred(status == BookingStatus.PENDING_PAYMENT).expiresAt(status == BookingStatus.PENDING_PAYMENT ? now.plusMinutes(30) : null)
                .assignedCheckInStaff(status == BookingStatus.PENDING_PAYMENT || status == BookingStatus.CANCELLED || i % 3 == 0 && status == BookingStatus.CONFIRMED ? null : staff)
                .termsAccepted(true).prohibitedItemsAccepted(true).termsAcceptedAt(placed)
                .termsVersion(policy.getTermsVersion()).termsContentSnapshot(policy.getTermsAndConditions())
                .prohibitedItemsSnapshot(policy.getProhibitedItems())
                .termsHash(TermsSnapshot.hash(policy.getTermsVersion(), policy.getTermsAndConditions(), policy.getProhibitedItems()))
                .overdueDailyLateFee(policy.getDailyLateFee()).overdueGraceDays(policy.getOverdueGraceDays())
                .overdueAccessDisableDays(policy.getOverdueAccessDisableDays()).overdueSealingDays(policy.getOverdueSealingDays())
                .overduePolicyCapturedAt(placed).overduePolicyLegacy(false)
                .cancellationFullRefundHours(policy.getCancellationFullRefundHours())
                .cancellationPartialRefundHours(policy.getCancellationPartialRefundHours())
                .cancellationPartialRefundPercent(policy.getCancellationPartialRefundPercent())
                .cancellationWithin24hPercent(policy.getCancellationWithin24hPercent())
                .cancellationAfter24hPercent(policy.getCancellationAfter24hPercent())
                .cancellationPolicyEffectiveAt(policy.getCancellationPolicyEffectiveAt())
                .cancellationPolicyCapturedAt(placed).cancellationPolicyLegacy(false).build();
        boolean handedOver = status == BookingStatus.ACTIVE || status == BookingStatus.COMPLETED;
        if (handedOver) {
            booking.setAccessCode("PG" + facility.getCode().replace("-", "") + number(i));
            booking.setAccessPin(pinHash);
            booking.setPinUpdatedAt(start);
            booking.setHandedOverByStaffId(staff.getId());
            booking.setAssignedCheckInStaff(staff);
            booking.setHandoverTime(start);
            booking.setContractPhotos(List.of(demoBaseUrl.replaceAll("/+$", "") + "/api/v1/catalog/demo-images/contract.png"));
        }
        if (status == BookingStatus.ACTIVE && i % 5 == 0) {
            booking.setScheduledReturnTime(now.plusDays(1).withHour(10).withMinute(0));
            booking.setAssignedCheckOutStaff(staff);
        }
        if (status == BookingStatus.ACTIVE && i % 5 == 1 && i <= 16) {
            booking.setPendingExtraMonths(1);
            booking.setPendingExtensionFee(type.getBasePricePerMonth().add(policy.getManagementFeePerMonth()));
        }
        if (status == BookingStatus.ACTIVE && i > 16) {
            LocalDateTime expired = booking.getEndDate().atStartOfDay();
            booking.setOverdueDetectedAt(expired.plusDays(1));
            long elapsedDays = java.time.temporal.ChronoUnit.DAYS.between(expired.toLocalDate(), now.toLocalDate());
            booking.setOverdueFeeAccrued(policy.getDailyLateFee().multiply(BigDecimal.valueOf(Math.max(0, elapsedDays - policy.getOverdueGraceDays()))));
            if (i >= 18) booking.setAccessDisabledAt(expired.plusDays(policy.getOverdueAccessDisableDays()));
            if (i >= 19) booking.setSealingPendingAt(expired.plusDays(policy.getOverdueSealingDays()));
            if (i == 20) booking.setSealingApprovedAt(expired.plusDays(policy.getOverdueSealingDays()).plusHours(1));
        }
        if ((status == BookingStatus.CONFIRMED && i <= 3) || (status == BookingStatus.CANCELLED && i == 20)) {
            HandoverIssueStatus issue = status == BookingStatus.CANCELLED ? HandoverIssueStatus.CANCELLED : HandoverIssueStatus.values()[i - 1];
            booking.setUnitAssignmentConfirmed(true);
            booking.setAssignedCheckInStaff(staff);
            booking.setHandoverIssueStatus(issue);
            booking.setHandoverIssueReportedAt(placed.plusMinutes(2));
            booking.setHandoverIssueReason("Demo: khách yêu cầu kiểm tra khóa trước khi nhận kho.");
            booking.setHandoverIssueDueAt(start);
            if (issue != HandoverIssueStatus.OPEN) booking.setHandoverIssueCustomerAgreedAt(placed.plusMinutes(3));
            if (issue == HandoverIssueStatus.RESOLVED || issue == HandoverIssueStatus.CANCELLED) {
                booking.setHandoverIssueResolvedBy(staff.getId());
                booking.setHandoverIssueResolutionNote("Đã kiểm tra khóa, trao đổi với khách và cập nhật lịch nhận kho.");
            }
        }
        if (status == BookingStatus.COMPLETED) {
            booking.setReturnTime(booking.getEndDate().atTime(10, 0));
            booking.setScheduledReturnTime(booking.getReturnTime());
            booking.setAssignedCheckOutStaff(staff);
        }
        add(booking, "bookings", placed);
        LocalDateTime paymentTime = status == BookingStatus.PENDING_PAYMENT ? placed : placed.plusMinutes(1);
        Payment depositPayment = payment(booking, "TXN-" + code, deposit, PaymentType.DEPOSIT,
                status == BookingStatus.PENDING_PAYMENT ? PaymentStatus.PENDING : PaymentStatus.PAID, paymentTime);
        Payment rentPayment = payment(booking, "TXN-" + code + "-R", rental.add(fee), PaymentType.RENTAL_FEE,
                depositPayment.getStatus(), paymentTime);
        if (status != BookingStatus.PENDING_PAYMENT) {
            // Synthetic VNPay metadata for display only; the dispatcher excludes every DEMO-PG booking.
            depositPayment.setPaymentMethod("VNPAY");
            depositPayment.setGatewayCreateDate(placed.plusMinutes(1).format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")));
            depositPayment.setGatewayTransactionNo("DEMO" + UUID.nameUUIDFromBytes(code.getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString().substring(0, 12).replace("-", ""));
            depositPayment.setGatewayAmount(deposit.add(rental).add(fee));
        }
        if (status == BookingStatus.CONFIRMED && i % 4 == 0) {
            payment(booking, "FAILED-" + code, deposit.add(rental).add(fee), PaymentType.DEPOSIT,
                    PaymentStatus.FAILED, placed.plusSeconds(30));
        }
        if (booking.getOverdueFeeAccrued().signum() > 0) {
            Payment late = payment(booking, "LATE-" + code, booking.getOverdueFeeAccrued(), PaymentType.EXTRA_CHARGE,
                    PaymentStatus.PENDING, now.minusHours(1));
            late.setNote(com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE);
            late.setPaymentMethod("SYSTEM");
        }
        if (handedOver) handover(booking, staff, "CHECK_IN", start);
        if (status == BookingStatus.COMPLETED) handover(booking, staff, "CHECK_OUT", booking.getReturnTime());
        if (status == BookingStatus.CANCELLED || status == BookingStatus.COMPLETED)
            refund(booking, depositPayment, rentPayment, i, placed, status == BookingStatus.CANCELLED);
        if (status == BookingStatus.ACTIVE) {
            ticket(booking, staff, i);
            events(booking, staff, i);
        }
    }

    private Payment payment(Booking booking, String transaction, BigDecimal amount, PaymentType type,
                            PaymentStatus status, LocalDateTime time) {
        return add(Payment.builder().booking(booking).transactionId(transaction).amount(amount)
                .paymentType(type).status(status).paymentMethod("DEMO_BANK_TRANSFER")
                .paymentTime(time).note(type == PaymentType.DEPOSIT ? "Tiền cọc đặt kho demo" : "Tiền thuê và phí dịch vụ demo")
                .build(), "payments", time);
    }

    private void handover(Booking booking, User staff, String kind, LocalDateTime time) {
        int index = Integer.parseInt(booking.getBookingCode().substring(booking.getBookingCode().length() - 2));
        BigDecimal damage = "CHECK_OUT".equals(kind) && index % 4 == 0
                ? BigDecimal.valueOf(50000).min(booking.getQuotedDepositAmount()) : BigDecimal.ZERO;
        add(HandoverRecord.builder().booking(booking).staff(staff).recordType(kind)
                .unitCondition(damage.signum() > 0 ? "DAMAGED" : "CLEAN")
                .notes(damage.signum() > 0 ? "Biên bản demo: khóa bị hư khi trả kho, khách xác nhận khấu trừ chi phí sửa chữa." : "Biên bản demo: kho sạch, khóa và camera hoạt động bình thường.")
                .damageFee(damage).damageReason(damage.signum() > 0 ? "Sửa khóa bị hư" : "Không ghi nhận hư hỏng")
                .recordedAt(time).photos(List.of(WAREHOUSE)).build(), "handover_records", time);
    }

    private void refund(Booking booking, Payment original, Payment rent, int i, LocalDateTime placed, boolean cancelled) {
        RefundStatus status = RefundStatus.values()[(i - 1) % RefundStatus.values().length];
        // Include settled 50% cancellations and settled damage deductions, not only full refunds.
        if (i == 17 || i == 20) status = RefundStatus.COMPLETED;
        LocalDateTime requested = cancelled ? placed.plusHours(i % 2 == 0 ? 1 : 25)
                : booking.getReturnTime().plusMinutes(30);
        BigDecimal percent = BigDecimal.valueOf(cancelled ? (i % 2 == 0
                ? booking.getCancellationWithin24hPercent() : booking.getCancellationAfter24hPercent()) : 100);
        if (booking.getHandoverIssueStatus() == HandoverIssueStatus.CANCELLED) percent = BigDecimal.valueOf(100);
        BigDecimal damage = !cancelled && i % 4 == 0 ? BigDecimal.valueOf(50000).min(booking.getQuotedDepositAmount()) : BigDecimal.ZERO;
        BigDecimal depositPart = booking.getQuotedDepositAmount().multiply(percent).divide(BigDecimal.valueOf(100)).subtract(damage);
        BigDecimal retained = booking.getQuotedDepositAmount().subtract(depositPart);
        // Match the production cancellation flow: the rental receipt includes prepaid service fees.
        BigDecimal rentPart = cancelled ? rent.getAmount() : BigDecimal.ZERO;
        if (retained.signum() > 0) {
            add(DepositDeduction.builder().booking(booking).originalPayment(original).amount(retained)
                    .deductionType(cancelled ? "CANCELLATION" : "DAMAGE")
                    .reason(cancelled ? "Hủy sau 24 giờ: giữ lại phần cọc theo chính sách đã chấp thuận." : "Demo: khấu trừ 50.000 đ sửa khóa bị hư khi trả kho.")
                    .recordedAt(requested).build(), "deposit_deductions", requested);
            booking.setDepositPaid(depositPart);
        }
        booking.setRefundBankCode("VCB");
        booking.setRefundAccountNumber(String.format("001100%07d", i));
        booking.setRefundAccountName(booking.getCustomer().getFullName());
        String requestId = booking.getBookingCode() + "-RF";
        Payment refundPayment = payment(booking, "RF-" + requestId, depositPart.add(rentPart), PaymentType.DEPOSIT,
                status == RefundStatus.COMPLETED ? PaymentStatus.REFUNDED : PaymentStatus.REFUND_PENDING, requested);
        refundPayment.setNote(com.storehub.common.PaymentNotes.DEPOSIT_REFUND);
        refundPayment.setPaymentMethod(status == RefundStatus.AWAITING_BANK_TRANSFER || status == RefundStatus.COMPLETED
                ? "BANK_TRANSFER" : "VNPAY");
        RefundRequest request = RefundRequest.builder().booking(booking).originalPayment(original).refundPayment(refundPayment)
                .requestId(requestId).amount(depositPart.add(rentPart)).depositAmount(depositPart).rentalAmount(rentPart)
                .damageDeduction(damage)
                .status(status).updatedStatusAt(requested).dueAt(requested.plusDays(policy(booking.getStorageUnit().getFacility()).getDepositRefundSlaDays()))
                .bankCode(booking.getRefundBankCode()).bankAccountNumber(booking.getRefundAccountNumber())
                .bankAccountName(booking.getRefundAccountName()).build();
        if (status == RefundStatus.MISSING_METADATA) {
            original.setGatewayCreateDate(null);
            original.setGatewayTransactionNo(null);
            original.setGatewayAmount(null);
        }
        if (status == RefundStatus.REJECTED) {
            request.setGatewayResponseCode("91");
            request.setGatewayTransactionStatus("09");
        }
        if (status == RefundStatus.AWAITING_CONFIRMATION) {
            request.setGatewayResponseCode("00");
            request.setGatewayTransactionStatus("05");
        }
        if (status == RefundStatus.COMPLETED) {
            request.setCompletedAt(requested.plusMinutes(20));
            request.setTransferReference("DEMO-TRANSFER-" + booking.getBookingCode());
            booking.setDepositPaid(BigDecimal.ZERO);
            original.setStatus(retained.signum() == 0 ? PaymentStatus.REFUNDED : PaymentStatus.PAID);
            if (rentPart.compareTo(rent.getAmount()) == 0) rent.setStatus(PaymentStatus.REFUNDED);
        } else {
            original.setStatus(PaymentStatus.REFUND_PENDING);
            if (cancelled) rent.setStatus(PaymentStatus.REFUND_PENDING);
        }
        add(request, "refund_requests", requested);
    }

    private void ticket(Booking booking, User staff, int i) {
        TicketStatus status = TicketStatus.values()[(i - 1) % TicketStatus.values().length];
        TicketCategory category = TicketCategory.values()[(i - 1) % TicketCategory.values().length];
        add(SupportTicket.builder().ticketCode("TKT-" + booking.getBookingCode()).customer(booking.getCustomer())
                .booking(booking).category(category).title("Yêu cầu demo " + number(i) + " • " + category)
                .description("Khách cần hỗ trợ kiểm tra ngăn " + booking.getStorageUnit().getUnitCode() + ". Liên hệ theo số điện thoại trong hồ sơ.")
                .status(status).priority(i % 3 == 0 ? "HIGH" : i % 3 == 1 ? "MEDIUM" : "LOW")
                .assignedStaff(status == TicketStatus.OPEN ? null : staff)
                .resolutionNote(status == TicketStatus.RESOLVED || status == TicketStatus.CLOSED ? "Đã kiểm tra, xử lý và xác nhận lại với khách hàng." : null)
                .photos(List.of(WAREHOUSE)).build(), "support_tickets", now.minusHours(21 - i));
    }

    private void events(Booking booking, User staff, int i) {
        Set<User> recipients = new LinkedHashSet<>();
        recipients.add(booking.getCustomer());
        recipients.add(staff);
        recipients.add(booking.getStorageUnit().getFacility().getManager());
        recipients.add(find(User.class, "email", "admin@gmail.com"));
        recipients.add(find(User.class, "email", "business@gmail.com"));
        recipients.remove(null);
        for (User user : recipients) {
            LocalDateTime time = now.minusHours(21 - i);
            add(Notification.builder().recipient(user).title("Demo phân trang " + number(i))
                    .content("Hợp đồng " + booking.getBookingCode() + " tại " + booking.getStorageUnit().getFacility().getName() + " đã bàn giao thành công.")
                    .type(NotificationType.CHECKIN_COMPLETED).referenceId(booking.getId()).referenceType("BOOKING")
                    .facility(booking.getStorageUnit().getFacility()).isRead(i % 2 == 0)
                    .readAt(i % 2 == 0 ? time.plusMinutes(10) : null).build(), "notifications", time);
            ActivityAction action = i % 3 == 0 ? ActivityAction.LOGOUT : i % 3 == 1 ? ActivityAction.LOGIN_SUCCESS : ActivityAction.LOGIN_FAILED;
            add(ActivityLog.builder().user(user).emailAttempted(user.getEmail()).action(action)
                    .logType(action == ActivityAction.LOGOUT ? ActivityLogType.LOGOUT : ActivityLogType.LOGIN)
                    .resourceType("SESSION").resourceId(user.getId()).description("Demo phân trang: " + action + " #" + number(i))
                    .status(action == ActivityAction.LOGIN_FAILED ? ActivityLogStatus.FAILED : ActivityLogStatus.SUCCESS)
                    .ipAddress("192.0.2." + i).userAgent("StoreHub Demo / Android")
                    .oldValue("Chưa thực hiện thao tác").newValue(action.name()).build(), "activity_logs", time);
        }
        add(ActivityLog.builder().user(staff).emailAttempted(staff.getEmail()).action(ActivityAction.HANDOVER_COMPLETE)
                .logType(ActivityLogType.DATA_ACTION).resourceType("BOOKING").resourceId(booking.getId())
                .description("Demo: bàn giao ngăn " + booking.getStorageUnit().getUnitCode()).status(ActivityLogStatus.SUCCESS)
                .ipAddress("192.0.2.100").userAgent("StoreHub Demo / Android").oldValue("CONFIRMED").newValue("ACTIVE")
                .build(), "activity_logs", booking.getHandoverTime());
    }

    private <T> T find(Class<T> type, String field, Object value) {
        return em.createQuery("select e from " + type.getSimpleName() + " e where e." + field + " = :value", type)
                .setParameter("value", value).getResultStream().findFirst().orElse(null);
    }

    private <T extends BaseEntity> T add(T entity, String table, LocalDateTime time) {
        em.persist(entity);
        entity.setCreatedAt(time);
        timestamps.add(new Stamp(entity, table, time));
        return entity;
    }

    private static String number(int i) { return String.format(Locale.ROOT, "%02d", i); }
    private record Stamp(BaseEntity entity, String table, LocalDateTime time) {}
}
