package com.storehub.common;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.util.PaginationUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.core.MethodParameter;
import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.server.*;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;
import org.springframework.web.util.UriComponentsBuilder;
import java.util.*;

/** Uniform pagination for GET collection resources, after service authorization and filtering. */
@RestControllerAdvice(basePackages = "com.storehub.controller")
@RequiredArgsConstructor
public class ListPaginationAdvice implements ResponseBodyAdvice<Object> {
    private final ObjectMapper mapper;
    @Override public boolean supports(MethodParameter method, Class<? extends HttpMessageConverter<?>> converter) { return true; }
    @Override public Object beforeBodyWrite(Object body, MethodParameter method, MediaType type,
            Class<? extends HttpMessageConverter<?>> converter, ServerHttpRequest request, ServerHttpResponse response) {
        if (request.getMethod() != HttpMethod.GET || !(body instanceof ApiResponse<?> envelope)
                || !(envelope.getData() instanceof List<?> items)) return body;
        var params = UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams();
        int page = number(params.getFirst("page"), 0);
        int size = number(params.getFirst("size"), 10);
        PaginationUtils.validatePage(page, size);
        List<JsonNode> ordered = items.stream().map(mapper::valueToTree).map(n -> (JsonNode) n)
                .sorted(Comparator.comparing(ListPaginationAdvice::time).reversed()
                    .thenComparing(ListPaginationAdvice::identity, Comparator.reverseOrder())).toList();
        long offset = (long) page * size;
        int start = (int) Math.min(offset, ordered.size());
        int end = Math.min(start + size, ordered.size());
        int pages = (int) Math.ceil((double) ordered.size() / size);
        PageResponse<JsonNode> result = PageResponse.<JsonNode>builder().content(ordered.subList(start, end))
                .page(page).size(size).totalElements(ordered.size()).totalPages(pages)
                .first(page == 0).last(page + 1 >= pages).build();
        return ApiResponse.builder().success(envelope.isSuccess()).message(envelope.getMessage())
                .timestamp(envelope.getTimestamp()).data(result).build();
    }
    private static int number(String value, int fallback) {
        try { return value == null ? fallback : Integer.parseInt(value); }
        catch (NumberFormatException ex) { throw new AppException(ErrorCode.INVALID_REQUEST); }
    }
    private static String time(JsonNode item) {
        for (String field : List.of("createdAt", "recordedAt", "paymentTime")) {
            if (item.hasNonNull(field)) return item.get(field).asText();
        }
        return "";
    }
    private static String identity(JsonNode item) {
        return item.path("id").asText(item.path("bookingId").asText(""));
    }
}
