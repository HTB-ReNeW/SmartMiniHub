package com.storehub.controller;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.service.CatalogService;
import org.junit.jupiter.api.Test;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.stream.IntStream;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class CatalogPaginationTest {
    @Test void getListReturnsPageEnvelopeWithNewestFirstAndNextTenReachable() throws Exception {
        CatalogService service = mock(CatalogService.class);
        when(service.getAllFacilities()).thenReturn(IntStream.range(0, 23).mapToObj(i ->
            FacilityResponse.builder().id(UUID.randomUUID()).name("Facility " + i)
                .createdAt(LocalDateTime.of(2026, 1, 1, 0, 0).plusDays(i)).build()).toList());
        var mapper = new ObjectMapper().registerModule(new JavaTimeModule()).disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        var mvc = MockMvcBuilders.standaloneSetup(new CatalogController(service))
            .setMessageConverters(new MappingJackson2HttpMessageConverter(mapper)).build();
        mvc.perform(get("/api/v1/catalog/facilities")).andExpect(status().isOk())
            .andExpect(jsonPath("$.data.size").value(10)).andExpect(jsonPath("$.data.content.length()").value(10))
            .andExpect(jsonPath("$.data.totalElements").value(23)).andExpect(jsonPath("$.data.content[0].name").value("Facility 22"));
        mvc.perform(get("/api/v1/catalog/facilities").param("page", "1").param("size", "10"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.content[0].name").value("Facility 12"));
    }
    @Test void noGetCollectionControllerStillDeclaresAnUnpagedList() throws Exception {
        var scanner = new org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider(false);
        scanner.addIncludeFilter(new org.springframework.core.type.filter.AnnotationTypeFilter(org.springframework.web.bind.annotation.RestController.class));
        int methods = 0;
        for (var candidate : scanner.findCandidateComponents("com.storehub.controller")) {
            for (var method : Class.forName(candidate.getBeanClassName()).getDeclaredMethods()) {
                if (method.isAnnotationPresent(org.springframework.web.bind.annotation.GetMapping.class)) {
                    methods++;
                    org.junit.jupiter.api.Assertions.assertFalse(method.getGenericReturnType().getTypeName().contains("java.util.List"), method.toString());
                }
            }
        }
        org.junit.jupiter.api.Assertions.assertTrue(methods > 30);
    }

}
