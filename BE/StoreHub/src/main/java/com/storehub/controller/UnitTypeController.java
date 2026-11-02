package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.CreateUnitTypeRequest;
import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.service.UnitTypeManagementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/unit-types")
@RequiredArgsConstructor
@Tag(name = "Unit Types", description = "Quản lý loại kho, kích thước, diện tích, giá thuê và tiền cọc")
@SecurityRequirement(name = "Bearer Authentication")
public class UnitTypeController {

    private final UnitTypeManagementService unitTypeManagementService;

    @PostMapping
    @PreAuthorize("hasRole('BUSINESS_MANAGER') and hasAuthority('UNIT_TYPE_CREATE')")
    @Operation(summary = "Tạo mới loại kho (kích thước, diện tích, giá thuê, tiền cọc)")
    public ResponseEntity<ApiResponse<UnitTypeCatalogResponse>> createUnitType(
            @Valid @RequestBody CreateUnitTypeRequest request
    ) {
        UnitTypeCatalogResponse response = unitTypeManagementService.createUnitType(request);
        return ResponseEntity.ok(ApiResponse.success(
                "Unit type created successfully",
                response
        ));
    }

    @PutMapping("/{unitTypeId}")
    @PreAuthorize("hasRole('BUSINESS_MANAGER') and hasAuthority('UNIT_TYPE_UPDATE')")
    @Operation(summary = "Cập nhật loại kho (tên, kích thước, diện tích, giá thuê, tiền cọc)")
    public ResponseEntity<ApiResponse<UnitTypeCatalogResponse>> updateUnitType(
            @PathVariable UUID unitTypeId,
            @Valid @RequestBody CreateUnitTypeRequest request
    ) {
        UnitTypeCatalogResponse response = unitTypeManagementService.updateUnitType(unitTypeId, request);
        return ResponseEntity.ok(ApiResponse.success(
                "Unit type updated successfully",
                response
        ));
    }

    @PutMapping("/{unitTypeId}/price")
    @PreAuthorize("hasRole('BUSINESS_MANAGER') and hasAuthority('UNIT_TYPE_UPDATE')")
    @Operation(summary = "Cập nhật giá thuê tháng và tiền cọc của loại kho")
    public ResponseEntity<ApiResponse<UnitTypeCatalogResponse>> updatePrice(
            @PathVariable UUID unitTypeId,
            @Valid @RequestBody UpdateUnitTypePriceRequest request
    ) {
        UnitTypeCatalogResponse response = unitTypeManagementService.updatePrice(unitTypeId, request);
        return ResponseEntity.ok(ApiResponse.success(
                "Unit type price updated successfully",
                response
        ));
    }
}
