package com.storehub.dto.response;

import java.util.UUID;

public record AssignableStaffResponse(UUID id,
        String username,
        String fullName,
        String email,
        boolean isActive,
        String roleName,
        java.time.LocalDateTime createdAt
) {
    public AssignableStaffResponse(UUID id,
        String username,
        String fullName,
        String email,
        boolean isActive,
        String roleName) {
        this(id, username, fullName, email, isActive, roleName, null);
    }
}
