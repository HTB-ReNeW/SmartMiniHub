package com.storehub.scheduler;

import com.storehub.repository.RefundRequestRepository;
import com.storehub.service.impl.RefundReminderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.ZoneId;

@Component
@RequiredArgsConstructor
@Slf4j
public class RefundReminderScheduler {
    private final RefundRequestRepository refunds;
    private final RefundReminderService reminders;

    @Scheduled(fixedDelayString = "${app.refunds.reminder-delay-ms:60000}")
    public void remindDueRefunds() {
        var now = LocalDateTime.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        int page = 0;
        org.springframework.data.domain.Page<java.util.UUID> ids;
        do {
            ids = refunds.findDueReminderIds(now, PageRequest.of(page++, 10));
            for (var id : ids) {
                try {
                    reminders.remind(id, now);
                } catch (Exception ex) {
                    log.error("Could not remind refund {}", id, ex);
                }
            }
        } while (ids.hasNext());
    }
}
