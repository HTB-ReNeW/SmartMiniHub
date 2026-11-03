package com.storehub.controller;

import com.storehub.common.CollectionPages;

import com.storehub.common.PageResponse;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.service.BookingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;
import java.util.List;

@RestController
@RequestMapping("/api/v1/bookings")
@RequiredArgsConstructor
@Tag(name = "Booking", description = "APIs đặt chỗ và quản lý đơn thuê kho")
public class BookingController {

    private final BookingService bookingService;

    @PostMapping
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CREATE')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Tạo đơn đặt chỗ kho mới (trạng thái PENDING_PAYMENT, hết hạn sau 30 phút)")
    public ResponseEntity<ApiResponse<BookingResponse>> createBooking(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody BookingCreationRequest request
    ) {
        BookingResponse booking = bookingService.createBooking(userDetails.getUsername(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Booking created successfully. Please complete payment to confirm.", booking));
    }

    @PostMapping("/{id}/defer-payment")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CREATE')")
    public ApiResponse<Void> deferPayment(@PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {
        bookingService.deferPayment(id, userDetails.getUsername());
        return ApiResponse.success("Đã lưu đơn thanh toán sau", null);
    }

    @GetMapping("/{id}/cancellation-quote")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CANCEL')")
    public ApiResponse<java.util.Map<String, Object>> cancellationQuote(
            @PathVariable UUID id, @AuthenticationPrincipal UserDetails userDetails) {
        return ApiResponse.success(bookingService.cancellationQuote(id, userDetails.getUsername()));
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CANCEL')")
    public ApiResponse<Void> cancelWithRefundAccount(@PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody com.storehub.dto.request.CancellationRefundAccountRequest account) {
        bookingService.cancelBooking(id, userDetails.getUsername(), account);
        return ApiResponse.success("Đã gửi yêu cầu hủy và hoàn tiền", null);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_CANCEL')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Hủy đơn đặt chỗ đang PENDING_PAYMENT – trả kho về AVAILABLE và notify waitlist")
    public ResponseEntity<ApiResponse<Void>> cancelBooking(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id
    ) {
        bookingService.cancelBooking(id, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Booking cancelled successfully", null));
    }

    @GetMapping("/my-pending")
    @PreAuthorize("hasRole('CUSTOMER') and hasAuthority('BOOKING_VIEW')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Các booking còn hạn đang chờ thanh toán của khách hiện tại")
    public ResponseEntity<ApiResponse<PageResponse<BookingResponse>>> getPayableBookings(@AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(ApiResponse.success("Payable bookings retrieved", CollectionPages.page(bookingService.getPayableBookings(userDetails.getUsername()), page, size)));
    }
}
