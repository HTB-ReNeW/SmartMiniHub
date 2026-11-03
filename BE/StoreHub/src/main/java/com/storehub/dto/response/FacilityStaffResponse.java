package com.storehub.dto.response;

import java.util.UUID;

public record FacilityStaffResponse(UUID id,
        String fullName,
        String email,
        String role,
        java.time.LocalDateTime createdAt
) {
    public FacilityStaffResponse(UUID id,
        String fullName,
        String email,
        String role) {
        this(id, fullName, email, role, null);
    }
}