package com.storehub.dto.response;

import com.storehub.common.PageResponse;
import lombok.Getter;
import org.springframework.data.domain.Page;

@Getter
public class RefundReviewPageResponse extends PageResponse<RefundRequestResponse> {
    private final long allCount, pendingCount, completedCount;
    public RefundReviewPageResponse(Page<RefundRequestResponse> page, long all, long completed) {
        super(page.getContent(),page.getNumber(),page.getSize(),page.getTotalElements(),
                page.getTotalPages(),page.isFirst(),page.isLast());
        allCount=all; completedCount=completed; pendingCount=all-completed;
    }
}
