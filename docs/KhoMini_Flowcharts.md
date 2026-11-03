# KhoMini — Flowchart các luồng chức năng

Đối chiếu mã nguồn ngày 02/11/2026. Sơ đồ ở mức nghiệp vụ phục vụ demo; các thao tác vẫn chịu kiểm tra quyền, trạng thái và phạm vi ở backend. Nhánh lỗi kết thúc lần thao tác hiện tại; người dùng có thể sửa dữ liệu để thực hiện lại. Các dòng sau trong một sơ đồ có thể mô tả lựa chọn liên quan, không có nghĩa mọi lựa chọn đều bắt buộc.

Lưu ý: hộp thoại vô hiệu hóa là bước xác nhận trên giao diện; không biểu thị hệ thống đã có cơ chế chặn tự vô hiệu hóa. Khóa thông minh hiện là mô phỏng. Hoàn trả tiền và trả kho là hai quy trình riêng.

## 01. Vòng đời thuê kho

Nhóm: Tổng quan

```mermaid
flowchart TD
  N0["Customer tìm cơ sở và loại kho"]
  N1["Xem báo giá và tạo booking"]
  N0 --> N1
  N2["Thanh toán cọc cùng tiền thuê qua VNPay"]
  N1 --> N2
  N3["CONFIRMED: chờ nhận kho"]
  N2 --> N3
  N4["Manager gán ngăn và phân công nhân viên"]
  N3 --> N4
  N5["Staff lập biên bản nhận kho"]
  N4 --> N5
  N6["ACTIVE: khách sử dụng kho"]
  N5 --> N6
  N7["Khách yêu cầu trả kho; Staff nghiệm thu"]
  N6 --> N7
  N8["COMPLETED; ngăn chuyển bảo trì"]
  N7 --> N8
  N9["Xử lý hoàn cọc và đưa ngăn về phục vụ"]
  N8 --> N9
```

## 02. Đăng nhập và điều hướng vai trò

Nhóm: Tài khoản

```mermaid
flowchart TD
  N0["Mở app; khôi phục phiên nếu có"]
  N1{"Phiên lưu còn hợp lệ?"}
  N1 -->|Không| E1["Hiện màn hình đăng nhập"]
  N0 --> N1
  N2["Backend xác nhận phiên và người dùng"]
  N1 -->|Có| N2
  N3{"Tài khoản và vai trò còn hoạt động?"}
  N3 -->|Không| E3["Từ chối truy cập; yêu cầu đăng nhập lại"]
  N2 --> N3
  N4["Đọc vai trò từ phiên xác thực"]
  N3 -->|Có| N4
  N5["Mở trang Admin / Business / Manager / Staff / Customer"]
  N4 --> N5
```

## 03. Đăng ký và đăng nhập mới

Nhóm: Tài khoản

```mermaid
flowchart TD
  N0["Nhập thông tin đăng ký"]
  N1{"Dữ liệu hợp lệ và tài khoản chưa tồn tại?"}
  N1 -->|Không| E1["Hiện lỗi; sửa thông tin rồi thử lại"]
  N0 --> N1
  N2["Tạo tài khoản Customer; gửi email chào mừng"]
  N1 -->|Có| N2
  N3["Nhập email và mật khẩu để đăng nhập"]
  N2 --> N3
  N4{"Thông tin đúng; tài khoản được phép đăng nhập?"}
  N4 -->|Không| E4["Hiện lỗi đăng nhập; không tạo phiên"]
  N3 --> N4
  N5["Tạo phiên truy cập và lưu token"]
  N4 -->|Có| N5
  N6["Điều hướng về trang theo vai trò"]
  N5 --> N6
```

## 04. Quên mật khẩu và đổi mật khẩu

Nhóm: Tài khoản

```mermaid
flowchart TD
  N0["Quên mật khẩu: nhập email"]
  N1["Hiện thông báo chung; gửi liên kết nếu có tài khoản"]
  N0 --> N1
  N2["Mở liên kết và nhập mật khẩu mới"]
  N1 --> N2
  N3{"Token đặt lại còn hợp lệ?"}
  N3 -->|Không| E3["Từ chối; yêu cầu liên kết mới"]
  N2 --> N3
  N4["Lưu mật khẩu băm mới; thu hồi phiên cũ"]
  N3 -->|Có| N4
  N5["Đăng nhập bằng mật khẩu mới"]
  N4 --> N5
  N6["Đổi mật khẩu khi đã đăng nhập: xác minh mật khẩu cũ trước khi lưu"]
  N5 --> N6
```

## 05. Phiên đăng nhập, hồ sơ và đăng xuất

Nhóm: Tài khoản

```mermaid
flowchart TD
  N0["Mở hồ sơ để xem thông tin tài khoản"]
  N1["Khi gọi API: gửi access token"]
  N0 --> N1
  N2{"Access token còn hợp lệ?"}
  N2 -->|Không| E2["Thử refresh; thất bại thì đăng nhập lại"]
  N1 --> N2
  N3["Backend kiểm tra vai trò, quyền và phạm vi dữ liệu"]
  N2 -->|Có| N3
  N4{"Được phép thực hiện?"}
  N4 -->|Không| E4["Trả lỗi quyền; không đổi dữ liệu"]
  N3 --> N4
  N5["Thực hiện chức năng"]
  N4 -->|Có| N5
  N6["Đăng xuất: thu hồi refresh token và xóa phiên trên app"]
  N5 --> N6
```

## 06. Tạo tài khoản và gán vai trò

Nhóm: Admin

```mermaid
flowchart TD
  N0["Admin mở Người dùng và vai trò"]
  N1["Tạo người dùng: nhập thông tin và vai trò"]
  N0 --> N1
  N2{"Dữ liệu hợp lệ, không trùng tài khoản?"}
  N2 -->|Không| E2["Hiện lỗi; không tạo người dùng"]
  N1 --> N2
  N3["Lưu tài khoản và tải lại danh sách"]
  N2 -->|Có| N3
  N4["Chọn người dùng để xem chi tiết hoặc gán vai trò"]
  N3 --> N4
  N5{"Tài khoản được giao diện cho đổi vai trò?"}
  N5 -->|Không| E5["Tài khoản ADMIN: giao diện không cho đổi vai trò"]
  N4 --> N5
  N6["Chọn vai trò; lưu thay đổi và tải lại danh sách"]
  N5 -->|Có| N6
```

## 07. Vô hiệu hóa, kích hoạt và xóa tài khoản

Nhóm: Admin

```mermaid
flowchart TD
  N0["Admin chọn tài khoản trong danh sách"]
  N1["Chọn Vô hiệu hóa khi tài khoản đang hoạt động"]
  N0 --> N1
  N2["Hiện email và cảnh báo không thể đăng nhập"]
  N1 --> N2
  N3{"Người dùng xác nhận Vô hiệu hóa?"}
  N3 -->|Không| E3["Hủy hoặc đóng hộp thoại: giữ nguyên tài khoản"]
  N2 --> N3
  N4["Gọi API; cập nhật trạng thái và tải lại danh sách"]
  N3 -->|Có| N4
  N5["Kích hoạt lại: dùng thao tác Kích hoạt"]
  N4 --> N5
  N6["Xóa là thao tác riêng, có xác nhận và kiểm tra dữ liệu liên quan"]
  N5 --> N6
```

## 08. Phân quyền vai trò

Nhóm: Admin

```mermaid
flowchart TD
  N0["Admin mở Vai trò và quyền hạn"]
  N1["Chọn vai trò và tải các quyền đang được cấp"]
  N0 --> N1
  N2["Chọn / bỏ quyền hoặc áp dụng mẫu quyền chuẩn"]
  N1 --> N2
  N3["Bấm lưu"]
  N2 --> N3
  N4{"Có quyền thay đổi phân quyền?"}
  N4 -->|Không| E4["Từ chối thay đổi"]
  N3 --> N4
  N5["Cấp hoặc thu hồi quyền tại backend"]
  N4 -->|Có| N5
  N6["Tải lại cấu hình; quyền được kiểm tra khi truy cập chức năng"]
  N5 --> N6
```

## 09. Gán quản lý cơ sở

Nhóm: Admin

```mermaid
flowchart TD
  N0["Admin mở danh sách cơ sở"]
  N1["Chọn cơ sở và quản lý phụ trách"]
  N0 --> N1
  N2{"Người được chọn và phạm vi gán hợp lệ?"}
  N2 -->|Không| E2["Hiện lỗi; không gán quản lý"]
  N1 --> N2
  N3["Lưu liên kết Facility Manager với cơ sở"]
  N2 -->|Có| N3
  N4["Manager đăng nhập và tải cơ sở được giao"]
  N3 --> N4
  N5["Chỉ truy cập nghiệp vụ trong phạm vi được phân công"]
  N4 --> N5
```

## 10. Tạo và sửa cơ sở có hình ảnh

Nhóm: Business

```mermaid
flowchart TD
  N0["Business mở Cơ sở và chính sách thuê"]
  N1["Chọn Thêm cơ sở hoặc Sửa cơ sở"]
  N0 --> N1
  N2["Nhập thông tin, địa chỉ, giờ mở cửa và trạng thái"]
  N1 --> N2
  N3["Chọn ảnh từ thiết bị; tải ảnh lên Cloudinary"]
  N2 --> N3
  N4{"Thông tin và ảnh được xử lý thành công?"}
  N4 -->|Không| E4["Hiện lỗi; sửa thông tin hoặc tải lại ảnh"]
  N3 --> N4
  N5["Gửi thông tin cơ sở cùng URL ảnh"]
  N4 -->|Có| N5
  N6["Backend kiểm tra quyền và lưu cơ sở"]
  N5 --> N6
  N7["Tải lại danh sách cơ sở"]
  N6 --> N7
```

## 11. Chính sách thuê và giá loại kho

Nhóm: Business

```mermaid
flowchart TD
  N0["Business chọn chính sách cơ sở hoặc giá loại kho"]
  N1["Nhập quy định cọc, hủy, gia hạn, trả kho hoặc giá tháng"]
  N0 --> N1
  N2{"Thông số và quyền cập nhật hợp lệ?"}
  N2 -->|Không| E2["Hiện lỗi; giữ dữ liệu cũ"]
  N1 --> N2
  N3["Lưu cấu hình mới"]
  N2 -->|Có| N3
  N4["Báo giá / nghiệp vụ áp dụng theo cấu hình và dữ liệu đã chốt của đơn"]
  N3 --> N4
  N5["Không tự sửa số tiền các giao dịch đã thanh toán"]
  N4 --> N5
```

## 12. Quản lý ngăn kho và bảo trì

Nhóm: Manager

```mermaid
flowchart TD
  N0["Manager mở tab Ngăn kho của cơ sở được giao"]
  N1["Thêm / sửa ngăn kho và loại kho"]
  N0 --> N1
  N2{"Thông tin, mã ngăn và trạng thái hợp lệ?"}
  N2 -->|Không| E2["Từ chối thay đổi"]
  N1 --> N2
  N3["Lưu và cập nhật danh sách"]
  N2 -->|Có| N3
  N4["Sau trả kho hoặc sự cố: ngăn ở trạng thái bảo trì"]
  N3 --> N4
  N5["Staff / Manager xử lý tình trạng và cập nhật ngăn"]
  N4 --> N5
  N6["Backend kiểm tra ngăn đang được giữ cho booking hay có thể mở bán"]
  N5 --> N6
```

## 13. Gán nhân viên và lịch bàn giao

Nhóm: Manager

```mermaid
flowchart TD
  N0["Manager mở Nhân viên của cơ sở"]
  N1["Chọn nhân viên để thêm hoặc gỡ khỏi cơ sở"]
  N0 --> N1
  N2{"Nhân viên và việc phân công hợp lệ?"}
  N2 -->|Không| E2["Hiện lỗi; không đổi liên kết"]
  N1 --> N2
  N3["Lưu danh sách nhân sự"]
  N2 -->|Có| N3
  N4["Mở lịch nhận / trả kho; chọn booking và Staff"]
  N3 --> N4
  N5{"Đúng cơ sở và lịch phân công hợp lệ?"}
  N5 -->|Không| E5["Từ chối giao lịch"]
  N4 --> N5
  N6["Lưu; Staff xem công việc được giao"]
  N5 -->|Có| N6
```

## 14. Tìm kho, báo giá và danh sách chờ

Nhóm: Customer

```mermaid
flowchart TD
  N0["Customer chọn cơ sở, loại kho và kỳ thuê"]
  N1["Hệ thống tải kho trống và báo giá"]
  N0 --> N1
  N2{"Còn ngăn có thể đặt?"}
  N2 -->|Không| E2["Đăng ký waitlist theo cơ sở và loại kho"]
  N1 --> N2
  N3["Customer kiểm tra giá và chính sách"]
  N2 -->|Có| N3
  N4["Chuyển sang tạo booking"]
  N3 --> N4
  N5["Waitlist là nhánh riêng: nhận thông báo khi đến lượt có kho"]
  N4 --> N5
  N6["Khách đặt trong thời hạn hoặc lượt thông báo hết hạn; có thể rời hàng đợi"]
  N5 --> N6
```

## 15. Đặt chỗ và thanh toán ban đầu

Nhóm: Customer

```mermaid
flowchart TD
  N0["Customer chọn lịch và xác nhận báo giá"]
  N1{"Còn kho và yêu cầu đặt hợp lệ?"}
  N1 -->|Không| E1["Hiện lỗi; chọn lại kho hoặc lịch"]
  N0 --> N1
  N2["Tạo booking PENDING_PAYMENT; giữ chỗ có thời hạn"]
  N1 -->|Có| N2
  N3["Tạo thanh toán cọc cùng tiền thuê"]
  N2 --> N3
  N4["Mở VNPay để thanh toán"]
  N3 --> N4
  N5{"Backend xác nhận thanh toán thành công đúng điều kiện?"}
  N5 -->|Không| E5["Chưa xác nhận: chờ, thử lại hoặc hết hạn giữ chỗ"]
  N4 --> N5
  N6["Đánh dấu khoản cọc và tiền thuê đã thanh toán"]
  N5 -->|Có| N6
  N7["Booking CONFIRMED; chờ bàn giao nhận kho"]
  N6 --> N7
```

## 16. Xử lý VNPay và đối soát

Nhóm: Thanh toán

```mermaid
flowchart TD
  N0["Khởi tạo giao dịch đúng chủ sở hữu và loại phí"]
  N1["Backend tính tiền; tạo giao dịch chờ thanh toán"]
  N0 --> N1
  N2["Khách thao tác trên VNPay Sandbox"]
  N1 --> N2
  N3["Backend nhận return / IPN hoặc thực hiện đối soát"]
  N2 --> N3
  N4{"Chữ ký, mã giao dịch và số tiền hợp lệ?"}
  N4 -->|Không| E4["Từ chối kết quả; không xác nhận đã thu tiền"]
  N3 --> N4
  N5["Kiểm tra kết quả và chống cập nhật trùng"]
  N4 -->|Có| N5
  N6["Thành công: ghi nhận thu tiền và cập nhật nghiệp vụ tương ứng"]
  N5 --> N6
  N7["App tải trạng thái giao dịch; hiển thị kết quả"]
  N6 --> N7
```

## 17. Hủy booking chưa thanh toán

Nhóm: Customer

```mermaid
flowchart TD
  N0["Customer mở đơn chờ thanh toán"]
  N1["Chọn hủy booking"]
  N0 --> N1
  N2{"Đúng chủ đơn và còn PENDING_PAYMENT?"}
  N2 -->|Không| E2["Từ chối hủy theo luồng này"]
  N1 --> N2
  N3["Chuyển booking sang CANCELLED"]
  N2 -->|Có| N3
  N4["Giải phóng ngăn / chỗ đang giữ theo tình trạng thực tế"]
  N3 --> N4
  N5["Thông báo lượt waitlist tiếp theo nếu có"]
  N4 --> N5
  N6["Tải lại danh sách đơn chờ thanh toán"]
  N5 --> N6
```

## 18. Gán ngăn và bàn giao nhận kho

Nhóm: Nhận kho

```mermaid
flowchart TD
  N0["Manager mở đơn đã thanh toán CONFIRMED"]
  N1["Kiểm tra / gán ngăn kho và phân công Staff"]
  N0 --> N1
  N2["Staff mở lịch nhận kho được giao"]
  N1 --> N2
  N3["Xác minh khách; kiểm tra ngăn; nhập biên bản và ảnh"]
  N2 --> N3
  N4{"Đủ điều kiện bàn giao và kho đạt yêu cầu?"}
  N4 -->|Không| E4["Chặn bàn giao; ghi nhận sự cố khi có"]
  N3 --> N4
  N5["Xác nhận biên bản nhận kho"]
  N4 -->|Có| N5
  N6["Booking ACTIVE; ngăn OCCUPIED"]
  N5 --> N6
  N7["Khách thấy kho trong Kho của tôi; sử dụng khóa thông minh"]
  N6 --> N7
```

## 19. Sự cố không thể bàn giao

Nhóm: Nhận kho

```mermaid
flowchart TD
  N0["Staff ghi nhận ngăn không đạt điều kiện bàn giao"]
  N1["Lưu tình trạng, lý do và bằng chứng"]
  N0 --> N1
  N2["Ngăn chuyển bảo trì; sự cố ở trạng thái OPEN"]
  N1 --> N2
  N3["Manager chọn đổi ngăn, đổi lịch hoặc hủy và hoàn tiền"]
  N2 --> N3
  N4["Sắp xếp phương án xử lý và lịch bàn giao phù hợp"]
  N3 --> N4
  N5{"Đã xử lý xong và bàn giao được?"}
  N5 -->|Không| E5["Nếu chọn hủy: CANCELLED và yêu cầu hoàn toàn bộ; nếu chưa xử lý: tiếp tục theo dõi"]
  N4 --> N5
  N6["Hoàn tất nhận kho; đóng sự cố RESOLVED"]
  N5 -->|Có| N6
  N7["Booking ACTIVE; ngăn được bàn giao OCCUPIED"]
  N6 --> N7
```

## 20. Khóa thông minh và quên PIN

Nhóm: Sử dụng kho

```mermaid
flowchart TD
  N0["Customer mở khóa thông minh của booking ACTIVE"]
  N1{"Đúng chủ kho và còn được phép sử dụng?"}
  N1 -->|Không| E1["Từ chối truy cập"]
  N0 --> N1
  N2["Tạo PIN lần đầu hoặc xem trạng thái khóa"]
  N1 -->|Có| N2
  N3["Mở khóa: nhập PIN; đóng khóa: gửi lệnh đóng"]
  N2 --> N3
  N4{"PIN và điều kiện thao tác hợp lệ?"}
  N4 -->|Không| E4["Hiện lỗi; giữ nguyên trạng thái khóa"]
  N3 --> N4
  N5["Cập nhật trạng thái khóa mô phỏng"]
  N4 -->|Có| N5
  N6["Đổi PIN: xác minh theo yêu cầu; quên PIN: dùng mật khẩu tài khoản"]
  N5 --> N6
  N7["Staff cấp lại PIN tại quầy theo quyền và xác minh khách"]
  N6 --> N7
```

## 21. Mã ra vào cổng

Nhóm: Sử dụng kho

```mermaid
flowchart TD
  N0["Customer yêu cầu mã cổng cho kho ACTIVE"]
  N1["Backend cấp mã có hạn dùng"]
  N0 --> N1
  N2["Khách đưa mã cho Staff / Manager tại cơ sở"]
  N1 --> N2
  N3["Nhân viên gửi mã để xác thực"]
  N2 --> N3
  N4{"Đúng cơ sở, còn hạn, chưa dùng và booking hợp lệ?"}
  N4 -->|Không| E4["Từ chối mã; không cho sử dụng lại"]
  N3 --> N4
  N5["Đánh dấu mã đã sử dụng"]
  N4 -->|Có| N5
  N6["Hiển thị kết quả xác thực; mã chỉ dùng một lần"]
  N5 --> N6
```

## 22. Gia hạn hợp đồng

Nhóm: Sử dụng kho

```mermaid
flowchart TD
  N0["Customer chọn gia hạn booking ACTIVE"]
  N1["Nhập số tháng gia hạn"]
  N0 --> N1
  N2{"Đúng cửa sổ gia hạn và không còn phí quá hạn phải xử lý?"}
  N2 -->|Không| E2["Hiện lý do; xử lý phí hoặc chờ đến thời điểm được gia hạn"]
  N1 --> N2
  N3["Tính phí; lưu yêu cầu gia hạn chờ thanh toán"]
  N2 -->|Có| N3
  N4["Thanh toán qua VNPay"]
  N3 --> N4
  N5{"Đã xác nhận thanh toán gia hạn thành công?"}
  N5 -->|Không| E5["Tiếp tục thanh toán hoặc hủy yêu cầu đang chờ"]
  N4 --> N5
  N6["Cập nhật ngày kết thúc và tổng thời gian thuê"]
  N5 -->|Có| N6
  N7["Kho tiếp tục ACTIVE với thời hạn mới"]
  N6 --> N7
```

## 23. Đặt lịch và nghiệm thu trả kho

Nhóm: Trả kho

```mermaid
flowchart TD
  N0["Customer chọn trả kho đang ACTIVE"]
  N1["Nhập lịch hẹn và thông tin ngân hàng nhận hoàn tiền"]
  N0 --> N1
  N2{"Đúng giờ mở cửa và thời gian báo trước?"}
  N2 -->|Không| E2["Hiện lỗi; chọn lịch / thông tin khác"]
  N1 --> N2
  N3["Lưu yêu cầu; thông báo Manager để phân công Staff"]
  N2 -->|Có| N3
  N4["Staff kiểm tra kho, chụp ảnh và ghi nhận hư hỏng"]
  N3 --> N4
  N5{"Các khoản nợ và điều kiện trả kho đã được xử lý?"}
  N5 -->|Không| E5["Chặn hoàn tất; xử lý nghĩa vụ còn thiếu"]
  N4 --> N5
  N6["Lập biên bản trả kho; tính khoản cọc được hoàn"]
  N5 -->|Có| N6
  N7["Booking COMPLETED; ngăn UNDER_MAINTENANCE"]
  N6 --> N7
  N8["Mở quy trình hoàn cọc nếu còn số tiền phải hoàn"]
  N7 --> N8
```

## 24. Hoàn tiền cọc và đối soát hoàn tiền

Nhóm: Trả kho

```mermaid
flowchart TD
  N0["Hệ thống tính cọc hoàn sau các khoản khấu trừ hợp lệ"]
  N1{"Còn tiền cần hoàn cho khách?"}
  N1 -->|Không| E1["Ghi nhận cọc đã được khấu trừ hết; không tạo khoản hoàn dương"]
  N0 --> N1
  N2["Tạo yêu cầu hoàn; kiểm tra thông tin giao dịch gốc"]
  N1 -->|Có| N2
  N3["Manager bổ sung dữ liệu / xử lý yêu cầu cần xem xét"]
  N2 --> N3
  N4["Hệ thống gửi hoàn VNPay hoặc theo quy trình chuyển khoản"]
  N3 --> N4
  N5{"Đã có xác nhận hoàn tiền thực tế?"}
  N5 -->|Không| E5["Chờ đối soát; bổ sung thông tin hoặc thử lại theo trạng thái"]
  N4 --> N5
  N6["Ghi nhận COMPLETED; cập nhật dữ liệu giao dịch"]
  N5 -->|Có| N6
  N7["Lịch sử và báo cáo phản ánh khoản hoàn đã xác nhận"]
  N6 --> N7
```

## 25. Quá hạn và niêm phong kho

Nhóm: Vận hành

```mermaid
flowchart TD
  N0["Tác vụ định kỳ kiểm tra booking ACTIVE đã qua ngày kết thúc"]
  N1["Đọc chính sách quá hạn đã chốt; tính số ngày tính phí"]
  N0 --> N1
  N2{"Đã vượt thời gian miễn phí theo chính sách?"}
  N2 -->|Không| E2["Chưa thu phí quá hạn ở thời điểm này"]
  N1 --> N2
  N3["Ghi nhận phí còn phải thanh toán; cập nhật mốc xử lý"]
  N2 -->|Có| N3
  N4["Đến điều kiện niêm phong: xử lý theo chính sách và phê duyệt"]
  N3 --> N4
  N5["Customer thanh toán phí quá hạn theo giao dịch được tạo"]
  N4 --> N5
  N6["Gia hạn / trả kho kiểm tra và tính bổ sung phí còn thiếu trước khi xử lý"]
  N5 --> N6
```

## 26. Gửi và xử lý yêu cầu hỗ trợ

Nhóm: Hỗ trợ

```mermaid
flowchart TD
  N0["Customer chọn kho và nhập nội dung, loại sự cố, ảnh"]
  N1{"Đúng chủ kho và dữ liệu yêu cầu hợp lệ?"}
  N1 -->|Không| E1["Từ chối tạo ticket"]
  N0 --> N1
  N2["Tạo ticket OPEN tại cơ sở tương ứng"]
  N1 -->|Có| N2
  N3["Staff tự nhận hoặc Manager phân công nhân viên"]
  N2 --> N3
  N4["Staff xử lý; trạng thái IN_PROGRESS"]
  N3 --> N4
  N5["Cập nhật kết quả xử lý RESOLVED / CLOSED theo quy tắc"]
  N4 --> N5
  N6["Customer theo dõi trạng thái và chi tiết yêu cầu"]
  N5 --> N6
```

## 27. Báo cáo và lịch sử giao dịch

Nhóm: Giám sát

```mermaid
flowchart TD
  N0["Admin / Business mở báo cáo toàn hệ thống; Manager xem cơ sở được giao"]
  N1["Chọn kỳ báo cáo hoặc bộ lọc lịch sử"]
  N0 --> N1
  N2{"Có quyền và đúng phạm vi dữ liệu?"}
  N2 -->|Không| E2["Từ chối truy cập"]
  N1 --> N2
  N3["Tổng hợp doanh thu, hoàn tiền, cọc và tỷ lệ lấp đầy"]
  N2 -->|Có| N3
  N4{"Truy vấn xử lý thành công?"}
  N4 -->|Không| E4["Hiện lỗi và nút thử lại"]
  N3 --> N4
  N5["Hiển thị số liệu và chi tiết giao dịch theo quyền"]
  N4 -->|Có| N5
  N6["Báo cáo toàn hệ thống: xuất CSV qua thao tác sao chép trên app"]
  N5 --> N6
```

## 28. Thông báo và nhật ký hoạt động

Nhóm: Giám sát

```mermaid
flowchart TD
  N0["Nghiệp vụ phát sinh sự kiện cần thông báo / ghi nhận"]
  N1["Tạo thông báo theo người nhận và nhật ký theo chức năng"]
  N0 --> N1
  N2["Người dùng mở thông báo của mình"]
  N1 --> N2
  N3["Đánh dấu từng thông báo hoặc tất cả là đã đọc"]
  N2 --> N3
  N4["Admin mở Nhật ký hoạt động hoặc Lịch sử đăng nhập"]
  N3 --> N4
  N5{"Có quyền xem nhật ký tương ứng?"}
  N5 -->|Không| E5["Từ chối truy cập"]
  N4 --> N5
  N6["Lọc danh sách; mở chi tiết để xem người thực hiện và nội dung"]
  N5 -->|Có| N6
```

## 29. Đơn hết hạn và waitlist

Nhóm: Tự động

```mermaid
flowchart TD
  N0["Tác vụ nền kiểm tra định kỳ"]
  N1["Booking chưa trả tiền hết hạn: hủy và giải phóng chỗ"]
  N0 --> N1
  N2["Booking đã trả tiền nhưng chưa nhận kho hết điều kiện: xử lý hết hạn"]
  N1 --> N2
  N3["Giải quyết khoản đã thu theo quy tắc hoàn / khấu trừ của nghiệp vụ"]
  N2 --> N3
  N4["Nếu có ngăn phục vụ được: thông báo người chờ tiếp theo"]
  N3 --> N4
  N5["Lượt waitlist được thông báo nhưng hết thời hạn: cập nhật hết hạn"]
  N4 --> N5
  N6["Chuyển lượt và tiếp tục theo dõi trong lần chạy tiếp theo"]
  N5 --> N6
```

## Nguồn đối chiếu

- FE/storehub_mobile/lib/screens: admin, operations, manager, staff, customer, common.
- BE/StoreHub/src/main/java/com/storehub/controller: Auth, User, RolePermission, Facility, FacilityManagement, FacilityOperations, Booking, Payment, CustomerStorage, RefundReview, Report, Waitlist, CustomerTicket, StaffTicket, Notification, ActivityLog.
- Backend service, repository, enums và scheduler tương ứng.
