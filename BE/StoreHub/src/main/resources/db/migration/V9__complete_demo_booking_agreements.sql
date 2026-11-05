-- Repair only the named development fixtures created by SeedConfig.
-- These texts are the v2026.1 seed agreement, not today's editable policy.
-- Real customer bookings and existing snapshots are never reconstructed here.
WITH fixture AS (
    SELECT 'v2026.1' AS version,
           '1. Khách hàng cam kết tuân thủ quy chế vận hành và an toàn PCCC tại cơ sở lưu kho StoreHub.
2. Tuyệt đối không lưu trữ hàng hóa thuộc danh mục cấm theo quy định của pháp luật và nội quy kho.
3. Khách hàng chịu hoàn toàn trách nhiệm pháp lý và bồi thường nếu hàng hóa gây thiệt hại, cháy nổ hoặc vi phạm pháp luật.
4. Thanh toán đúng hạn theo thỏa thuận thuê kho và phối hợp thực hiện bàn giao, kiểm tra kho khi có yêu cầu.
5. Thời hạn hợp đồng và cước phí được tính từ Ngày bắt đầu thuê đã thỏa thuận. Việc nhận kho trễ hơn ngày hẹn không làm kéo dài thời hạn kết thúc hợp đồng hay giảm trừ tiền thuê.' AS terms,
           'Chất dễ cháy nổ, bình gas, xăng dầu; Ma túy, chất kích thích, hóa chất độc hại; Động vật sống, thực phẩm tươi sống dễ thối rữa; Vũ khí, đạn dược, hàng cấm, pháo hoa; Hàng hóa có mùi nồng nặc gây ảnh hưởng kho xung quanh' AS prohibited
), missing AS (
    SELECT b.id,
           COALESCE(NULLIF(b.terms_content_snapshot, ''), f.terms) AS terms,
           COALESCE(NULLIF(b.prohibited_items_snapshot, ''), f.prohibited) AS prohibited,
           f.version
    FROM bookings b CROSS JOIN fixture f
    WHERE b.booking_code IN ('BK-TEST-ACTIVE-01', 'BK-TEST-ACTIVE-02', 'BK-TEST-CONFIRMED-01', 'BK-TEST-COMPLETED-01', 'BK-TEST-PENDING-01', 'BK-D7-ACTIVE-01', 'BK-TD-ACTIVE-01')
      AND (b.terms_version IS NULL OR b.terms_version = f.version)
      AND (NULLIF(b.terms_content_snapshot, '') IS NULL
           OR NULLIF(b.prohibited_items_snapshot, '') IS NULL)
)
UPDATE bookings AS b SET
    terms_content_snapshot = m.terms,
    prohibited_items_snapshot = m.prohibited,
    terms_version = m.version,
    terms_hash = encode(sha256(convert_to(
        char_length(m.version)::text || ':' || m.version ||
        char_length(m.terms)::text || ':' || m.terms ||
        char_length(m.prohibited)::text || ':' || m.prohibited, 'UTF8')), 'hex'),
    terms_accepted = TRUE,
    prohibited_items_accepted = TRUE,
    terms_accepted_at = COALESCE(b.terms_accepted_at, b.created_at)
FROM missing m WHERE b.id = m.id;
