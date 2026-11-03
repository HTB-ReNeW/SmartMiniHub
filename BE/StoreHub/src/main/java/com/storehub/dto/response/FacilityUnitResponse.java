package com.storehub.dto.response;

import com.storehub.enums.UnitStatus;
import java.util.UUID;

public record FacilityUnitResponse(UUID id,
        String unitCode,
        String floorLevel,
        UUID unitTypeId,
        String unitType,
        UnitStatus status,
        java.time.LocalDateTime createdAt
) {
    public FacilityUnitResponse(UUID id,
        String unitCode,
        String floorLevel,
        UUID unitTypeId,
        String unitType,
        UnitStatus status) {
        this(id, unitCode, floorLevel, unitTypeId, unitType, status, null);
    }
}