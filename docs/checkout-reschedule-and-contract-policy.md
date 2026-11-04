# Đổi lịch trả kho và chính sách trong hợp đồng

## Đặt / đổi lịch

- Form điền lại lịch hẹn, ngân hàng, số tài khoản (giữ số 0 đầu), chủ tài khoản và ghi chú đã lưu.
- Lịch đã qua vẫn hiện nguyên giá trị; bắt buộc chọn giờ mới trước khi lưu.
- Backend kiểm tra lại mọi giới hạn, không chỉ dựa vào lịch chọn trên Flutter.
- Trong hạn: từ hôm nay đến ngày kết thúc hợp đồng; áp dụng số ngày báo trước đã lưu trên đơn.
  Nếu thời gian còn lại ngắn hơn số ngày báo trước, rút ngắn báo trước đến ngày hết hạn.
- Quá hạn: hôm nay hoặc ngày mai, không áp dụng thời gian báo trước để tránh chặn trả kho.
- Mọi cuộc hẹn phải ở tương lai, trong giờ mở/đóng cửa (tính cả phút) của cơ sở.
- Đổi thời gian: hủy phân công cũ, báo quản lý phân công lại và báo staff cũ.
  Chỉ sửa ngân hàng/ghi chú, không đổi giờ: giữ nhân viên đã phân công.
- Không sửa ngày hết hạn, tiền phạt đã phát sinh hoặc mốc khóa PIN/niêm phong.
  Đơn ACTIVE đã khóa PIN hoặc được duyệt niêm phong vẫn được gửi yêu cầu trả;
  việc mở kho/nhận lại kho do cơ sở và staff phối hợp xử lý.

## Hợp đồng và hoàn tiền

- Customer và facility xem cùng dữ liệu `rentalPolicy` lấy từ từng booking:
  phí mỗi ngày, số ngày ân hạn, khóa PIN, chờ quản lý duyệt niêm phong, báo trước và thời hạn hoàn tiền.
- Trước khi đặt, khách cũng thấy các thông tin này từ chính sách cơ sở trong phần xác nhận hợp đồng.
- Ngày bắt đầu phạt = ngày hết hạn + số ngày ân hạn + 1. Tính theo ngày, không theo từng giờ hẹn.
- Trả kho: hạn hoàn cọc tính từ lúc staff hoàn tất nhận lại kho; trừ công nợ/khấu trừ theo hợp đồng.
- Hủy trước bàn giao: hạn hoàn tiền tính từ lúc ghi nhận yêu cầu hủy hợp lệ và đủ thông tin nhận tiền.
- Số ngày xử lý hoàn tiền khác với mốc trong/sau 24 giờ quyết định tỷ lệ hoàn cọc.
- Tiến trình tạo yêu cầu hoàn tiền dùng thời hạn đã chụp trên booking; sửa chính sách cơ sở không
  thay đổi các đơn đã đặt. Khoản thu phát sinh muộn sau khi đơn đã hoàn tất có hạn hoàn mới từ lúc tạo yêu cầu.

## Nâng cấp dữ liệu

Khởi động lại backend để Flyway chạy `V12__checkout_details_and_refund_policy_snapshot.sql`.
Không sửa migration cũ, không cần xóa database hay đặt lại đơn.

Migration thêm `checkout_notes`, `return_notice_days`, `refund_sla_days`, `refund_policy_legacy`.
Đơn cũ được cố định cấu hình hiện có một lần; ưu tiên thời hạn có chứng cứ từ yêu cầu hoàn tiền
đã tồn tại, và ghi rõ là dữ liệu chính sách được bổ sung từ hồ sơ hiện có. Không giả định đó là
phiên bản hợp đồng gốc. Ghi chú trả kho cũ được phục hồi từ yêu cầu gần nhất trong nhật ký nếu còn dữ liệu.
Ngày hẹn và thông tin ngân hàng đã có được giữ nguyên. Không thay đổi giao dịch, công nợ hay hạn hoàn
của yêu cầu hoàn tiền đã tạo trước nâng cấp.

## Kiểm tra nhanh

1. Chọn đơn ACTIVE đã bàn giao. Gửi lịch trả và thông tin ngân hàng, ghi chú.
2. Mở **Đổi lịch trả kho**: kiểm tra toàn bộ dữ liệu cũ được điền lại.
3. Đổi giờ đã phân công: kiểm tra staff cũ bị bỏ phân công, manager/staff nhận thông báo.
4. Chỉ sửa ghi chú/tài khoản, giữ giờ: phân công vẫn giữ nguyên.
5. Đặt `scheduled_return_time` của đơn test về hôm qua: mở form thấy giờ cũ, không lưu được cho tới khi chọn giờ mới.
6. Trong hạn: kiểm tra lịch chọn không vượt `end_date`; gần hết hạn vẫn có ngày hợp lệ dù báo trước dài.
7. Quá hạn: chỉ hôm nay/ngày mai. Gọi API với ngày xa hơn phải bị từ chối; dữ liệu đơn không đổi.
8. Kiểm tra đơn bị khóa PIN/niêm phong vẫn gửi được yêu cầu; các dấu mốc cũ không bị xóa.
9. Tạo đơn mới với thời hạn hoàn tiền 3 ngày và phí trễ hạn riêng. Đổi chính sách cơ sở sang 10 ngày:
   hợp đồng cũ và yêu cầu hoàn tiền mới cho đơn đó vẫn dùng 3 ngày cùng phí/mốc đã lưu.
10. Staff hoàn tất nhận lại kho: đối chiếu `refund_requests.due_at` với `bookings.return_time` + thời hạn đã lưu.
    Với hủy trước nhận kho: đối chiếu hạn với thời điểm tạo yêu cầu hợp lệ.

Chỉ thao tác các bản ghi test; không chuyển status sang COMPLETED bằng tay để kiểm tra luồng hoàn tiền.
