package com.storehub.dto.response;

import com.storehub.enums.WaitlistStatus;
import java.time.Instant;
import java.util.UUID;

public record WaitlistResponse(UUID id, UUID facilityId, String facilityName,
                               UUID unitTypeId, String unitTypeName, WaitlistStatus status,
                               Instant notifiedAt, Instant offerExpiresAt,
        java.time.LocalDateTime createdAt
) {
    public WaitlistResponse(UUID id, UUID facilityId, String facilityName,
                               UUID unitTypeId, String unitTypeName, WaitlistStatus status,
                               Instant notifiedAt, Instant offerExpiresAt) {
        this(id, facilityId, facilityName, unitTypeId, unitTypeName, status, notifiedAt, offerExpiresAt, null);
    }
}
