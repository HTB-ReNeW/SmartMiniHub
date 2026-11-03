# Collection API pagination

All GET collection endpoints return `ApiResponse<PageResponse<T>>`.

- `page` is zero-based and defaults to `0`.
- `size` defaults to `10`; valid sizes are `1` through `10`.
- Records are ordered newest first, with a descending ID tie-breaker. Payment history uses payment time; handover history uses recorded time.
- `data` contains `content`, `page`, `size`, `totalElements`, `totalPages`, `first`, and `last`.
- Searching/filtering happens before the visible page is selected.

Example: `/api/v1/catalog/facilities?page=1&size=10`.

Existing repository-backed paged endpoints continue to page in the database. Legacy list-based services are adapted by `CollectionPages` at the controller boundary; their underlying queries still load the matching collection before slicing. `ListPaginationAdvice` is a fallback for any additional GET collection resource.

The mobile app uses ten-row page controls. Existing load-more screens fetch the next server batch and open it as a new page. Selectors and client-filtered lists use `HttpClient.getAll` to collect ten-item API batches so filtering does not silently ignore records on later pages. Grouped permission lists paginate the records before building section cards.

POST responses such as uploaded image URLs, single-resource GET responses, and report aggregates retain their existing shapes.
