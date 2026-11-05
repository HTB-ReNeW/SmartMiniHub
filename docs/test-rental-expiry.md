# Kiểm thử hết hạn thuê, nhắc trả kho và quá hạn

## Hành vi sau khi sửa

- API danh sách kho tính `overdue` và `overdueDays` từ `status = ACTIVE`,
  `end_date` và ngày hiện tại ở Việt Nam. Không phụ thuộc `overdue_detected_at`
  hay việc tiến trình tính phí đã chạy.
- Flutter cũng kiểm tra ngày hết hạn theo lịch Việt Nam, hiển thị badge **Quá hạn**,
  cảnh báo và nút **Yêu cầu trả kho**. Một yêu cầu gia hạn chưa thanh toán không
  kéo dài ngày hết hạn thực tế. Đã hẹn trả thì hiển thị lịch, không yêu cầu gửi lại.
- Mặc định backend kiểm tra mỗi phút, thay cho chỉ 00:05 mỗi ngày. Nếu backend
  khởi động sau giờ hết hạn, lượt chạy tiếp theo vẫn xử lý các đơn còn quá hạn.
- Khách nhận thông báo trong ứng dụng từ ngày quá hạn đầu tiên, kể cả còn trong
  thời gian miễn phạt. Mỗi đơn/ngày hết hạn chỉ nhắc một lần, không phụ thuộc đã đọc.
  Gia hạn thành công rồi hết hạn kỳ mới có thể nhận thông báo mới.
- Thông báo dùng `type = SYSTEM`, `reference_type = BOOKING`, bấm **Xem kho của tôi**.
  Đây là thông báo trong ứng dụng, không phải push notification của hệ điều hành.
- Phí trễ hạn vẫn tính theo ngày và chính sách được chụp lại trên booking. Chạy
  mỗi phút không nhân thêm phí. Mốc khóa truy cập và chờ niêm phong giữ nguyên.

Khởi động lại backend, cập nhật/chạy lại Flutter. Nếu có ghi đè lịch chạy riêng,
đặt `OVERDUE_SCHEDULER_CRON` hoặc `app.overdue.scheduler-cron` là `0 * * * * *`.
Không cần migration mới hay chạy lại seed cho bản sửa này.

## 1. Chọn đơn để test trong PostgreSQL

Dùng một đơn thật sự đã bàn giao, đang `ACTIVE`, ngăn `OCCUPIED`, chưa bị xử lý
quá hạn. Ví dụ chọn theo email đang đăng nhập:

```sql
SELECT b.id, b.booking_code, u.email, b.status,
       su.unit_code, su.status AS unit_status,
       b.start_date, b.end_date,
       b.overdue_grace_days, b.overdue_daily_late_fee,
       b.overdue_access_disable_days, b.overdue_sealing_days,
       b.overdue_detected_at, b.access_disabled_at,
       b.sealing_pending_at, b.scheduled_return_time
FROM bookings b
JOIN users u ON u.id = b.customer_id
JOIN storage_units su ON su.id = b.storage_unit_id
WHERE u.email = 'customer@gmail.com'
  AND b.status = 'ACTIVE'
  AND su.status = 'OCCUPIED'
  AND b.overdue_detected_at IS NULL
  AND b.access_disabled_at IS NULL
  AND b.sealing_pending_at IS NULL
ORDER BY b.created_at DESC;
```

Chọn đơn có `start_date` trước ngày kết thúc muốn test. Ghi lại `end_date` ban đầu.
Nếu không có đơn phù hợp, tạo/nhận bàn giao một đơn test trước; không đổi status
của một đơn chưa bàn giao để giả làm đơn đang thuê.

## 2. Chỉ đổi ngày kết thúc của một đơn

Thay `MA_DON_CAN_TEST` bằng mã vừa chọn. Câu lệnh bên dưới đặt hết hạn hôm qua,
độc lập múi giờ của database:

```sql
UPDATE bookings
SET end_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 1
WHERE booking_code = 'f245fbc8-d68c-4525-b14e-e17024951de3'
  AND status = 'ACTIVE'
RETURNING id, booking_code, status, end_date;
```

Commit thay đổi nếu công cụ database đang bật giao dịch thủ công. Giữ nguyên
`status = ACTIVE`, PIN, tiền cọc, các snapshot chính sách và các trường xử lý quá hạn.
Không tự điền `return_time` hoặc `scheduled_return_time` khi muốn test yêu cầu trả mới.

## 3. Kết quả cần thấy

1. Mở **Kho của tôi**, bấm tải lại: hiện **Quá hạn**, số ngày và hướng dẫn gia hạn/trả.
2. Nếu chưa hẹn trả: có nút **Yêu cầu trả kho**, mở form trả kho như mục Quản lý.
3. Chờ khoảng 1 phút, mở/tải lại danh sách thông báo: có thông báo hết hạn.
4. Chờ thêm 2 lượt: vẫn chỉ có một thông báo cho đơn/ngày hết hạn đó.
5. Nếu đang trong ngày miễn phạt: không bị hiển thị một khoản phí phạt giả.

Có thể kiểm tra thông báo trực tiếp:

```sql
SELECT n.title, n.content, n.created_at, n.is_read
FROM notifications n
JOIN bookings b ON b.id = n.reference_id
WHERE b.booking_code = 'MA_DON_CAN_TEST'
  AND n.reference_type = 'BOOKING'
  AND n.type = 'SYSTEM'
ORDER BY n.created_at DESC;
```

## Các tình huống khác

Với chính sách miễn 1 ngày, khóa truy cập ngày 3, chờ niêm phong ngày 7,
phí 50.000 đ/ngày (hãy đối chiếu snapshot thực tế của đơn):

| `end_date` so với hôm nay | Kỳ vọng sau lượt xử lý |
| --- | --- |
| Hôm nay / tương lai | Không cảnh báo quá hạn, không tạo thông báo hết hạn mới |
| Hôm qua (`- 1`) | Nhắc gia hạn/trả kho, chưa phạt |
| Hai ngày trước (`- 2`) | Phạt 50.000 đ |
| Ba ngày trước (`- 3`) | Phạt 100.000 đ, thu hồi PIN/mã truy cập |
| Bảy ngày trước (`- 7`) | Phạt 300.000 đ, chờ manager duyệt niêm phong |

Dùng đơn riêng cho từng tình huống khi có thể. Không đưa ngày hết hạn tiến lên
để hoàn tác một đơn đã phát sinh phí/thu hồi PIN: ngày mới không tự xóa giao dịch
phạt cũ hoặc khôi phục PIN đã bị xóa. Không xóa dữ liệu thanh toán để reset test.

Để kiểm tra trả kho đầy đủ: customer gửi yêu cầu và thông tin nhận hoàn tiền →
facility phân công → staff nghiệm thu. Nếu còn nợ phí trễ hạn, khách phải thanh
toán trước khi staff hoàn tất. Sau đó đơn `COMPLETED`, có biên bản và yêu cầu hoàn cọc.
Hết hạn tự nó không đồng nghĩa đã trả kho, không tự chuyển `COMPLETED`.
