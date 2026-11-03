package com.storehub.config;

import com.storehub.entity.*;
import com.storehub.enums.*;
import jakarta.persistence.Column;
import jakarta.persistence.EntityManager;
import jakarta.persistence.TypedQuery;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.lang.reflect.Field;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Exercise the entire fixture graph without a live database or payment gateway. */
class PaginationDemoSeederTest {
    private final Map<Class<?>, List<BaseEntity>> store = new HashMap<>();
    private final EntityManager em = mock(EntityManager.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private PaginationDemoSeeder seeder;
    private User customer;

    @BeforeEach
    @SuppressWarnings({"rawtypes", "unchecked"})
    void setup() {
        when(encoder.encode(any())).thenReturn("$2a$demo-hash");
        doAnswer(invocation -> {
            insert(invocation.getArgument(0));
            return null;
        }).when(em).persist(any());
        when(em.createQuery(anyString(), any(Class.class))).thenAnswer(invocation -> {
            String jpql = invocation.getArgument(0);
            Class<?> type = invocation.getArgument(1);
            Map<String, Object> parameters = new HashMap<>();
            TypedQuery query = mock(TypedQuery.class, call -> {
                if (call.getMethod().getName().equals("setParameter")) {
                    parameters.put(call.getArgument(0), call.getArgument(1));
                    return call.getMock();
                }
                List<BaseEntity> result = store.getOrDefault(type, List.of()).stream().filter(entity -> {
                    var matcher = Pattern.compile("e\\.(\\w+) = :(\\w+)").matcher(jpql);
                    while (matcher.find()) {
                        if (!Objects.equals(ReflectionTestUtils.getField(entity, matcher.group(1)), parameters.get(matcher.group(2))))
                            return false;
                    }
                    return true;
                }).toList();
                return switch (call.getMethod().getName()) {
                    case "getResultList" -> result;
                    case "getResultStream" -> result.stream();
                    default -> RETURNS_DEFAULTS.answer(call);
                };
            });
            return query;
        });
        for (String name : List.of("CUSTOMER", "STAFF", "FACILITY_MANAGER", "ADMIN", "BUSINESS_MANAGER"))
            insert(Role.builder().name(name).description(name + " demo role").build());
        customer = user("customer", "CUSTOMER");
        user("admin", "ADMIN");
        user("business", "BUSINESS_MANAGER");
        for (String code : List.of("HCM-D1", "HCM-D7", "HCM-TD")) {
            User manager = user("facility" + code, "FACILITY_MANAGER");
            Facility facility = Facility.builder().code(code).name("StoreHub " + code).address("123 Demo Street")
                    .manager(manager).build();
            insert(facility);
            manager.setFacility(facility);
            user("staff" + code, "STAFF").setFacility(facility);
        }
        seeder = new PaginationDemoSeeder(em, jdbc, encoder);
        ReflectionTestUtils.setField(seeder, "customerPassword", "customer-password");
        ReflectionTestUtils.setField(seeder, "staffPassword", "staff-password");
        ReflectionTestUtils.setField(seeder, "managerPassword", "manager-password");
        ReflectionTestUtils.setField(seeder, "demoBaseUrl", "http://10.0.2.2:8080");
    }

    @Test
    void everyMajorListHasEnoughRecordsAndCoversItsStatuses() {
        seeder.seed();
        assertEquals(20, rows(UnitType.class).size());
        assertEquals(22, rows(Facility.class).stream().filter(f -> f.getCode().startsWith("DEMO-PG-")).count());
        for (String code : List.of("HCM-D1", "HCM-D7", "HCM-TD")) {
            for (BookingStatus status : List.of(BookingStatus.ACTIVE, BookingStatus.CONFIRMED, BookingStatus.COMPLETED, BookingStatus.CANCELLED))
                assertEquals(20, rows(Booking.class).stream().filter(b -> b.getStorageUnit().getFacility().getCode().equals(code) && b.getStatus() == status).count(), code + status);
            assertEquals(20, rows(SupportTicket.class).stream().filter(t -> t.getBooking().getStorageUnit().getFacility().getCode().equals(code)).count());
            assertTrue(rows(RefundRequest.class).stream().filter(r -> r.getBooking().getStorageUnit().getFacility().getCode().equals(code)).count() >= 20);
            assertTrue(rows(User.class).stream().filter(u -> u.getFacility() != null && u.getFacility().getCode().equals(code) && "STAFF".equals(u.getRole().getName())).count() >= 20);
            assertEquals(20, rows(Booking.class).stream().filter(b -> b.getStorageUnit().getFacility().getCode().equals(code)
                    && b.getStatus() == BookingStatus.CONFIRMED && !b.getStartDate().isAfter(java.time.LocalDate.now())).count());
        }
        assertEquals(EnumSet.allOf(BookingStatus.class), enumSet(rows(Booking.class).stream().map(Booking::getStatus).toList(), BookingStatus.class));
        assertEquals(EnumSet.allOf(PaymentStatus.class), enumSet(rows(Payment.class).stream().map(Payment::getStatus).toList(), PaymentStatus.class));
        assertEquals(EnumSet.allOf(RefundStatus.class), enumSet(rows(RefundRequest.class).stream().map(RefundRequest::getStatus).toList(), RefundStatus.class));
        assertEquals(EnumSet.allOf(TicketStatus.class), enumSet(rows(SupportTicket.class).stream().map(SupportTicket::getStatus).toList(), TicketStatus.class));
        assertEquals(EnumSet.allOf(TicketCategory.class), enumSet(rows(SupportTicket.class).stream().map(SupportTicket::getCategory).toList(), TicketCategory.class));
        assertEquals(EnumSet.allOf(UnitStatus.class), enumSet(rows(StorageUnit.class).stream().map(StorageUnit::getStatus).toList(), UnitStatus.class));
        assertEquals(EnumSet.allOf(HandoverIssueStatus.class), enumSet(rows(Booking.class).stream().map(Booking::getHandoverIssueStatus).filter(Objects::nonNull).toList(), HandoverIssueStatus.class));
        assertTrue(rows(Notification.class).stream().filter(n -> n.getRecipient() == customer).count() >= 20);
        assertTrue(rows(ActivityLog.class).size() >= 20);
    }

    @Test
    void rerunningAddsNothingAndPreservesExistingRecords() {
        seeder.seed();
        int count = store.values().stream().mapToInt(List::size).sum();
        customer.setFullName("Customer edited their name");
        Booking first = rows(Booking.class).get(0);
        first.setRefundBankCode("CUSTOMER_EDIT");
        LocalDateTime created = first.getCreatedAt();
        seeder.seed();
        assertEquals(count, store.values().stream().mapToInt(List::size).sum());
        assertEquals("Customer edited their name", customer.getFullName());
        assertEquals("CUSTOMER_EDIT", first.getRefundBankCode());
        assertEquals(created, first.getCreatedAt());
        assertEquals(rows(Booking.class).size(), rows(Booking.class).stream().map(Booking::getBookingCode).distinct().count());
    }

    @Test
    void requiredFieldsAreCompleteAndOptionalFieldsFollowTheLifecycle() throws Exception {
        seeder.seed();
        assertTrue(new org.springframework.core.io.ClassPathResource("static/api/v1/catalog/demo-images/contract.png").exists());
        for (List<BaseEntity> entities : store.values()) {
            for (BaseEntity entity : entities) {
                if (!isFixture(entity)) continue;
                for (Class<?> type = entity.getClass(); type != Object.class; type = type.getSuperclass()) {
                    for (Field field : type.getDeclaredFields()) {
                        field.setAccessible(true);
                        Object value = field.get(entity);
                        Column column = field.getAnnotation(Column.class);
                        if (column != null && !column.nullable()) assertNotNull(value, entity.getClass() + "." + field.getName());
                        if (value instanceof String text) {
                            assertFalse(text.isBlank(), field.getName());
                            if (column != null && !"TEXT".equalsIgnoreCase(column.columnDefinition()))
                                assertTrue(text.length() <= column.length(), entity.getClass() + "." + field.getName());
                        }
                    }
                }
            }
        }
        for (Booking booking : rows(Booking.class)) {
            assertNotNull(booking.getTermsHash());
            assertTrue(booking.getTermsAccepted());
            assertTrue(booking.getProhibitedItemsAccepted());
            assertEquals(booking.getStartDate().plusMonths(booking.getRentalMonths()).minusDays(1), booking.getEndDate());
            if (booking.getStatus() == BookingStatus.ACTIVE || booking.getStatus() == BookingStatus.COMPLETED) {
                assertNotNull(booking.getHandoverTime());
                assertFalse(booking.getContractPhotos().isEmpty());
            } else {
                assertNull(booking.getHandoverTime());
                assertNull(booking.getAccessPin());
            }
            if (booking.getStatus() != BookingStatus.COMPLETED) assertNull(booking.getReturnTime());
            if (booking.getStatus() == BookingStatus.PENDING_PAYMENT) assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        }
        // Each customer has at most one unpaid pay-later booking across all facilities.
        Map<User, Long> pending = rows(Booking.class).stream().filter(b -> b.getStatus() == BookingStatus.PENDING_PAYMENT)
                .collect(java.util.stream.Collectors.groupingBy(Booking::getCustomer, java.util.stream.Collectors.counting()));
        assertTrue(pending.values().stream().allMatch(count -> count == 1));
        assertTrue(rows(Payment.class).stream().filter(p -> p.getStatus() == PaymentStatus.PENDING || p.getStatus() == PaymentStatus.FAILED)
                .allMatch(p -> p.getGatewayCreateDate() == null));
        assertTrue(rows(Booking.class).stream().map(Booking::getCreatedAt).distinct().count() >= 20);
        for (Booking booking : rows(Booking.class)) {
            if (booking.getOverdueDetectedAt() != null) {
                long days = java.time.temporal.ChronoUnit.DAYS.between(booking.getEndDate(), java.time.LocalDate.now());
                assertEquals(0, booking.getOverdueDailyLateFee().multiply(BigDecimal.valueOf(Math.max(0, days - booking.getOverdueGraceDays()))).compareTo(booking.getOverdueFeeAccrued()));
            }
        }
    }

    @Test
    void refundsUseCorrectPolicyAmountsAndCompletedRefundsHaveNoRemainingDeposit() {
        seeder.seed();
        assertTrue(rows(RefundRequest.class).stream().anyMatch(r -> r.getStatus() == RefundStatus.COMPLETED
                && r.getBooking().getStatus() == BookingStatus.CANCELLED
                && r.getDepositAmount().compareTo(r.getBooking().getQuotedDepositAmount()) < 0));
        assertTrue(rows(RefundRequest.class).stream().anyMatch(r -> r.getStatus() == RefundStatus.COMPLETED && r.getDamageDeduction().signum() > 0));
        for (RefundRequest refund : rows(RefundRequest.class)) {
            Booking booking = refund.getBooking();
            assertEquals(0, refund.getAmount().compareTo(refund.getDepositAmount().add(refund.getRentalAmount())));
            assertEquals(booking.getRefundAccountNumber(), refund.getBankAccountNumber());
            assertEquals(booking.getCustomer().getFullName(), refund.getBankAccountName());
            assertEquals(com.storehub.common.PaymentNotes.DEPOSIT_REFUND, refund.getRefundPayment().getNote());
            if (booking.getStatus() == BookingStatus.CANCELLED) {
                boolean within24h = java.time.Duration.between(booking.getCreatedAt(), refund.getCreatedAt()).toHours() < 24;
                BigDecimal percentage = BigDecimal.valueOf(within24h ? booking.getCancellationWithin24hPercent() : booking.getCancellationAfter24hPercent());
                assertEquals(0, booking.getQuotedDepositAmount().multiply(percentage).divide(BigDecimal.valueOf(100)).compareTo(refund.getDepositAmount()));
                assertEquals(0, booking.getTotalRentalFee().add(booking.getQuotedManagementFee()).compareTo(refund.getRentalAmount()));
            } else assertEquals(0, refund.getRentalAmount().signum());
            if (refund.getStatus() == RefundStatus.COMPLETED) {
                assertEquals(0, booking.getDepositPaid().signum());
                assertNotNull(refund.getCompletedAt());
                assertNotNull(refund.getTransferReference());
            } else assertNull(refund.getCompletedAt());
        }
    }

    @Test
    void disabledOrMissingBaseDataDoesNotInsertAnything() {
        ReflectionTestUtils.setField(seeder, "enabled", false);
        seeder.seed();
        verify(em, never()).persist(any());
        ReflectionTestUtils.setField(seeder, "enabled", true);
        store.get(User.class).remove(customer);
        seeder.seed();
        verify(em, never()).persist(any());
    }

    private boolean isFixture(BaseEntity entity) {
        return !(entity instanceof Role) && !(entity instanceof Facility f && !f.getCode().startsWith("DEMO-PG-"))
                && !(entity instanceof User u && !u.getUsername().startsWith("pg_"));
    }

    private <T extends BaseEntity> T insert(T entity) {
        entity.setId(UUID.randomUUID());
        entity.setCreatedAt(LocalDateTime.now());
        entity.setUpdatedAt(LocalDateTime.now());
        store.computeIfAbsent(entity.getClass(), key -> new ArrayList<>()).add(entity);
        return entity;
    }

    private User user(String name, String roleName) {
        Role role = rows(Role.class).stream().filter(r -> r.getName().equals(roleName)).findFirst().orElseThrow();
        return insert(User.builder().username(name).email(name + "@gmail.com").phone("0901234567")
                .fullName("Demo " + name).password("hashed").role(role).build());
    }

    private <T> List<T> rows(Class<T> type) { return store.getOrDefault(type, List.of()).stream().map(type::cast).toList(); }
    private <E extends Enum<E>> EnumSet<E> enumSet(List<E> values, Class<E> type) {
        EnumSet<E> set = EnumSet.noneOf(type);
        set.addAll(values);
        return set;
    }
}
