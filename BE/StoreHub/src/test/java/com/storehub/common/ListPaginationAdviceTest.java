package com.storehub.common;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.storehub.exception.AppException;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.http.server.ServletServerHttpResponse;
import org.springframework.mock.web.*;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.IntStream;
import static org.junit.jupiter.api.Assertions.*;

class ListPaginationAdviceTest {
    public record Item(String id, LocalDateTime createdAt) {}
    final ObjectMapper mapper = new ObjectMapper().registerModule(new JavaTimeModule())
        .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    final ListPaginationAdvice advice = new ListPaginationAdvice(mapper);
    Object response(Object data, String method, String query) {
        MockHttpServletRequest request = new MockHttpServletRequest(method, "/api/v1/catalog/facilities");
        request.setQueryString(query);
        return advice.beforeBodyWrite(ApiResponse.success(data), null, MediaType.APPLICATION_JSON,
            MappingJackson2HttpMessageConverter.class, new ServletServerHttpRequest(request),
            new ServletServerHttpResponse(new MockHttpServletResponse()));
    }
    @Test void collectionPagesAreTenItemsAndGloballyNewestFirst() {
        List<Item> items = IntStream.range(0, 25).mapToObj(i -> new Item("item-" + i,
            LocalDateTime.of(2026, 1, 1, 0, 0).plusDays(i))).toList();
        var first = (PageResponse<?>) ((ApiResponse<?>) response(items, "GET", null)).getData();
        var second = (PageResponse<?>) ((ApiResponse<?>) response(items, "GET", "page=1&size=10")).getData();
        var third = (PageResponse<?>) ((ApiResponse<?>) response(items, "GET", "page=2")).getData();
        assertEquals(10, first.getContent().size());
        assertEquals(25, first.getTotalElements());
        assertEquals(3, first.getTotalPages());
        assertEquals("item-24", ((JsonNode) first.getContent().get(0)).get("id").asText());
        assertEquals("item-14", ((JsonNode) second.getContent().get(0)).get("id").asText());
        assertEquals(5, third.getContent().size());
        assertTrue(third.isLast());
    }
    @Test void rejectsInvalidPageRequestsAndHandlesEmptyOrPastLastPage() {
        assertThrows(AppException.class, () -> response(List.of(), "GET", "size=11"));
        assertThrows(AppException.class, () -> response(List.of(), "GET", "page=-1"));
        assertThrows(AppException.class, () -> response(List.of(), "GET", "page=no"));
        var page = (PageResponse<?>) ((ApiResponse<?>) response(List.of(), "GET", "page=99")).getData();
        assertTrue(page.getContent().isEmpty()); assertTrue(page.isLast());
    }
    @Test void stableTieBreakAndNonGetCollectionsStayUnchanged() {
        var date = LocalDateTime.of(2026, 1, 1, 0, 0);
        var data = List.of(new Item("a", date), new Item("b", date));
        var page = (PageResponse<?>) ((ApiResponse<?>) response(data, "GET", null)).getData();
        assertEquals("b", ((JsonNode) page.getContent().get(0)).get("id").asText());
        assertSame(data, ((ApiResponse<?>) response(data, "POST", null)).getData());
    }
}
