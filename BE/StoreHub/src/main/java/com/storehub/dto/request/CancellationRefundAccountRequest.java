package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class CancellationRefundAccountRequest {
    @NotBlank @Size(max = 100)
    private String bankCode;
    @NotBlank @Pattern(regexp = "[0-9]{4,34}", message = "Số tài khoản phải gồm 4 đến 34 chữ số")
    private String bankAccountNumber;
    @NotBlank @Size(min = 2, max = 100)
    private String bankAccountName;
}
