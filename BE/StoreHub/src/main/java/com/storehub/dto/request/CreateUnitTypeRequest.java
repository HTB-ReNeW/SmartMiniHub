package com.storehub.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateUnitTypeRequest {

    @NotBlank(message = "Vui lòng nhập tên loại kho")
    private String typeName;

    @NotBlank(message = "Vui lòng nhập kích thước loại kho (VD: 1m x 1m x 1m)")
    private String dimensions;

    @NotNull(message = "Vui lòng nhập diện tích")
    @DecimalMin(value = "0.01", message = "Diện tích phải lớn hơn 0")
    private Double areaSqm;

    @NotNull(message = "Vui lòng nhập giá thuê theo tháng")
    @DecimalMin(value = "0.01", message = "Giá thuê cơ bản phải lớn hơn 0")
    private BigDecimal basePricePerMonth;

    @NotNull(message = "Vui lòng nhập tiền cọc")
    @DecimalMin(value = "0.00", message = "Tiền cọc không được âm")
    private BigDecimal depositAmount;

    private String imageUrl;
}
