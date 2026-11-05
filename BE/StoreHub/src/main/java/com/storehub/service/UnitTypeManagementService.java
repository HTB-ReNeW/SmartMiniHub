package com.storehub.service;

import com.storehub.dto.request.CreateUnitTypeRequest;
import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;

import java.util.UUID;

public interface UnitTypeManagementService {

    UnitTypeCatalogResponse createUnitType(CreateUnitTypeRequest request);

    UnitTypeCatalogResponse updateUnitType(UUID unitTypeId, CreateUnitTypeRequest request);

    UnitTypeCatalogResponse updatePrice(UUID unitTypeId, UpdateUnitTypePriceRequest request);
}
