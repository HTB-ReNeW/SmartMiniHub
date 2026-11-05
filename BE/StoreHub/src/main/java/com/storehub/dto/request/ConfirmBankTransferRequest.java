package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfirmBankTransferRequest {

    @NotBlank(message = "Vui lòng nhập mã tham chiếu chuyển khoản")
    @jakarta.validation.constraints.Size(max = 100, message = "Mã chuyển khoản tối đa 100 ký tự")
    private String transferReference;

    @jakarta.validation.constraints.Size(max = 1000, message = "Ghi chú tối đa 1000 ký tự")
    private String notes;
}
