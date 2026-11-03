package com.storehub.controller;

import com.storehub.common.CollectionPages;

import com.storehub.common.PageResponse;

import com.storehub.common.ApiResponse;
import com.storehub.service.WaitlistService;
import com.storehub.dto.response.WaitlistResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;
import java.util.List;

@RestController
@RequestMapping("/api/v1/waitlist")
@RequiredArgsConstructor
@Tag(name = "Waitlist", description = "APIs đăng ký hàng đợi khi hết kho trống")
public class WaitlistController {

    private final WaitlistService waitlistService;

    @PostMapping
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CREATE')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Đăng ký vào hàng đợi khi không còn kho trống cho loại kho đã chọn")
    public ResponseEntity<ApiResponse<Void>> joinWaitlist(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam @NotNull UUID facilityId,
            @RequestParam @NotNull UUID unitTypeId
    ) {
        waitlistService.joinWaitlist(userDetails.getUsername(), facilityId, unitTypeId);
        return ResponseEntity.ok(
                ApiResponse.success("You have been added to the waitlist. We will notify you when a unit becomes available.", null));
    }

    @GetMapping("/mine")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_VIEW')")
    public ResponseEntity<ApiResponse<PageResponse<WaitlistResponse>>> myWaitlist(@AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(ApiResponse.success( CollectionPages.page(waitlistService.myWaitlist(userDetails.getUsername()), page, size)));
    }

    @DeleteMapping("/{waitlistId}")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CANCEL')")
    public ResponseEntity<ApiResponse<Void>> leaveWaitlist(
            @AuthenticationPrincipal UserDetails userDetails, @PathVariable UUID waitlistId) {
        waitlistService.leaveWaitlist(userDetails.getUsername(), waitlistId);
        return ResponseEntity.ok(ApiResponse.success("Left waitlist", null));
    }
}
