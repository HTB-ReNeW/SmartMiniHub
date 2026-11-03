package com.storehub.common;

import com.storehub.util.PaginationUtils;
import java.util.*;

/** Shared contract for collections returned by legacy list-based services. */
public final class CollectionPages {
    private CollectionPages() {}
    public static <T> PageResponse<T> page(List<T> values, int page, int size) {
        PaginationUtils.validatePage(page, size);
        List<T> ordered = new ArrayList<>(values);
        ordered.sort(Comparator.comparing((T value) -> read(value, "createdAt", "recordedAt", "paymentTime"))
                .reversed().thenComparing(value -> read(value, "id", "bookingId"), Comparator.reverseOrder()));
        int start = (int) Math.min((long) page * size, ordered.size());
        int end = Math.min(start + size, ordered.size());
        int pages = (int) Math.ceil((double) ordered.size() / size);
        return PageResponse.<T>builder().content(ordered.subList(start, end))
                .page(page).size(size).totalElements(ordered.size()).totalPages(pages)
                .first(page == 0).last(page + 1 >= pages).build();
    }
    private static String read(Object item, String... names) {
        for (String name : names) {
            if (item instanceof Map<?, ?> map && map.get(name) != null) return map.get(name).toString();
            for (String method : List.of(name, "get" + Character.toUpperCase(name.charAt(0)) + name.substring(1))) {
                try {
                    Object value = item.getClass().getMethod(method).invoke(item);
                    if (value != null) return value.toString();
                } catch (NoSuchMethodException ignored) {
                    // Records use component accessors; Lombok DTOs use getters.
                } catch (ReflectiveOperationException ex) {
                    throw new IllegalStateException("Cannot read collection ordering metadata", ex);
                }
            }
        }
        return "";
    }
}
