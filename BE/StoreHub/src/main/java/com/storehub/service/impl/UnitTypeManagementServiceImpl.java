package com.storehub.service.impl;

import com.storehub.dto.request.CreateUnitTypeRequest;
import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.entity.UnitType;
import com.storehub.enums.ActivityAction;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.UnitTypeManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UnitTypeManagementServiceImpl implements UnitTypeManagementService {

    private final UnitTypeRepository unitTypeRepository;
    private final ActivityLogService activityLogService;

    @Override
    @Transactional
    public UnitTypeCatalogResponse createUnitType(CreateUnitTypeRequest request) {
        UnitType unitType = UnitType.builder()
                .typeName(request.getTypeName().trim())
                .dimensions(request.getDimensions().trim())
                .areaSqm(request.getAreaSqm())
                .basePricePerMonth(request.getBasePricePerMonth())
                .depositAmount(request.getDepositAmount())
                .imageUrl(request.getImageUrl())
                .build();

        UnitType saved = unitTypeRepository.save(unitType);

        activityLogService.record(
                ActivityAction.UNIT_TYPE_CREATE,
                "UNIT_TYPE",
                saved.getId(),
                "Created unit type " + saved.getTypeName(),
                null,
                "typeName=" + saved.getTypeName() + ", dimensions=" + saved.getDimensions()
                        + ", areaSqm=" + saved.getAreaSqm() + ", price=" + saved.getBasePricePerMonth()
                        + ", deposit=" + saved.getDepositAmount()
        );

        return mapToResponse(saved);
    }

    @Override
    @Transactional
    public UnitTypeCatalogResponse updateUnitType(UUID unitTypeId, CreateUnitTypeRequest request) {
        UnitType unitType = unitTypeRepository.findById(unitTypeId)
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        String oldDetails = "typeName=" + unitType.getTypeName() + ", dimensions=" + unitType.getDimensions()
                + ", area=" + unitType.getAreaSqm() + ", price=" + unitType.getBasePricePerMonth()
                + ", deposit=" + unitType.getDepositAmount();

        unitType.setTypeName(request.getTypeName().trim());
        unitType.setDimensions(request.getDimensions().trim());
        unitType.setAreaSqm(request.getAreaSqm());
        unitType.setBasePricePerMonth(request.getBasePricePerMonth());
        unitType.setDepositAmount(request.getDepositAmount());
        if (request.getImageUrl() != null) {
            unitType.setImageUrl(request.getImageUrl());
        }

        UnitType saved = unitTypeRepository.save(unitType);

        activityLogService.record(
                ActivityAction.UNIT_TYPE_UPDATE,
                "UNIT_TYPE",
                saved.getId(),
                "Updated unit type " + saved.getTypeName(),
                oldDetails,
                "typeName=" + saved.getTypeName() + ", dimensions=" + saved.getDimensions()
                        + ", area=" + saved.getAreaSqm() + ", price=" + saved.getBasePricePerMonth()
                        + ", deposit=" + saved.getDepositAmount()
        );

        return mapToResponse(saved);
    }

    @Override
    @Transactional
    public UnitTypeCatalogResponse updatePrice(
            UUID unitTypeId,
            UpdateUnitTypePriceRequest request
    ) {
        UnitType unitType = unitTypeRepository.findById(unitTypeId)
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        BigDecimal oldPrice = unitType.getBasePricePerMonth();
        BigDecimal oldDeposit = unitType.getDepositAmount();

        unitType.setBasePricePerMonth(request.getBasePricePerMonth());
        unitType.setDepositAmount(request.getDepositAmount());
        if (request.getTypeName() != null && !request.getTypeName().isBlank()) {
            unitType.setTypeName(request.getTypeName().trim());
        }
        if (request.getDimensions() != null && !request.getDimensions().isBlank()) {
            unitType.setDimensions(request.getDimensions().trim());
        }
        if (request.getAreaSqm() != null && request.getAreaSqm() > 0) {
            unitType.setAreaSqm(request.getAreaSqm());
        }
        if (request.getImageUrl() != null) {
            unitType.setImageUrl(request.getImageUrl());
        }

        UnitType saved = unitTypeRepository.save(unitType);

        activityLogService.record(
                ActivityAction.PRICE_UPDATE,
                "UNIT_TYPE",
                saved.getId(),
                "Updated price and details of unit type " + saved.getTypeName(),
                "price=" + oldPrice + ", deposit=" + oldDeposit,
                "price=" + saved.getBasePricePerMonth()
                        + ", deposit=" + saved.getDepositAmount()
                        + ", dimensions=" + saved.getDimensions()
                        + ", areaSqm=" + saved.getAreaSqm()
        );

        return mapToResponse(saved);
    }

    private UnitTypeCatalogResponse mapToResponse(UnitType saved) {
        return UnitTypeCatalogResponse.builder()
                .id(saved.getId())
                .typeName(saved.getTypeName())
                .dimensions(saved.getDimensions())
                .areaSqm(saved.getAreaSqm())
                .basePricePerMonth(saved.getBasePricePerMonth())
                .depositAmount(saved.getDepositAmount())
                .imageUrl(saved.getImageUrl())
                .build();
    }
}
