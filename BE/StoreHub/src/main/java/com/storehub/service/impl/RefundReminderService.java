package com.storehub.service.impl;

import com.storehub.entity.User;
import com.storehub.enums.NotificationType;
import com.storehub.enums.RefundStatus;
import com.storehub.repository.NotificationRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RefundReminderService {
    private final RefundRequestRepository refunds;
    private final NotificationRepository notifications;
    private final NotificationService notificationService;
    private final com.storehub.repository.UserRepository users;

    @Transactional
    public void remind(UUID id, LocalDateTime now) {
        // Serialize the deadline check with refund completion and other reminder workers.
        var request = refunds.lockById(id).orElse(null);
        if (request == null || request.getStatus() == RefundStatus.COMPLETED
                || request.getDueAt() == null || request.getDueAt().isAfter(now)) return;
        var booking = request.getBooking();
        var facility = booking.getStorageUnit().getFacility();
        String deadline = request.getDueAt().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
        String title = "Đến hạn hoàn tiền • " + deadline;
        String amount = java.text.NumberFormat.getIntegerInstance(java.util.Locale.forLanguageTag("vi-VN"))
                .format(request.getAmount()) + " đ";
        String content = "Đơn " + booking.getBookingCode() + " tại " + facility.getName()
                + " đã đến hạn hoàn " + amount + " vào " + deadline + ". ";
        notifyOnce(booking.getCustomer(), id, title,
                content + "Cơ sở chưa xác nhận hoàn tiền. Vui lòng liên hệ cơ sở để kiểm tra.", facility);
        var managers = new java.util.LinkedHashMap<UUID, User>();
        if (facility.getManager() != null && !Boolean.FALSE.equals(facility.getManager().getIsActive())) {
            managers.put(facility.getManager().getId(), facility.getManager());
        }
        for (var manager : users.findByFacility_IdAndRole_NameAndIsActiveTrue(facility.getId(), "FACILITY_MANAGER")) {
            managers.put(manager.getId(), manager);
        }
        for (var manager : managers.values()) {
            notifyOnce(manager, id, title,
                    content + "Vui lòng kiểm tra yêu cầu hoàn tiền và xử lý, xác nhận chuyển tiền cho khách.", facility);
        }
    }

    private void notifyOnce(User recipient, UUID id, String title, String content,
                            com.storehub.entity.Facility facility) {
        if (recipient != null && !notifications.existsByRecipient_IdAndReferenceIdAndTitle(
                recipient.getId(), id, title)) {
            notificationService.notifyUser(recipient, title, content, NotificationType.SYSTEM,
                    id, "REFUND_REQUEST", facility);
        }
    }
}
