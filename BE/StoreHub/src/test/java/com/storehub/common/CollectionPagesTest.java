package com.storehub.common;

import com.storehub.dto.response.FacilityResponse;
import com.storehub.exception.AppException;
import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.IntStream;
import static org.junit.jupiter.api.Assertions.*;

class CollectionPagesTest {
    @Test void pagesAcrossAllResultsBeforeSlicingAndPreservesTypedDtos() {
        var items = IntStream.range(0, 24).mapToObj(i -> FacilityResponse.builder().id(UUID.randomUUID())
            .name("Facility " + i).createdAt(LocalDateTime.of(2026, 1, 1, 0, 0).plusDays(i)).build()).toList();
        var first = CollectionPages.page(items, 0, 10);
        var second = CollectionPages.page(items, 1, 10);
        var last = CollectionPages.page(items, 2, 10);
        assertEquals("Facility 23", first.getContent().get(0).getName());
        assertEquals("Facility 13", second.getContent().get(0).getName());
        assertEquals(10, first.getContent().size());
        assertEquals(4, last.getContent().size());
        assertEquals(24, last.getTotalElements());
        assertTrue(last.isLast());
        assertEquals("Facility 0", items.get(0).getName());
        assertThrows(AppException.class, () -> CollectionPages.page(items, 0, 11));
    }
}
