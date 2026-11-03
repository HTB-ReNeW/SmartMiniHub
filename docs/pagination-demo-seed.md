# Dữ liệu demo phân trang

Khởi động backend ở môi trường development như bình thường. `SeedConfig` gọi
`PaginationDemoSeeder` sau seed cũ, kể cả khi database đã có dữ liệu. Không cần
xóa database hay chạy lại migration. Seed chỉ bổ sung bản ghi mang mã riêng;
chạy lại không tạo trùng, không sửa đơn, tài khoản hoặc trạng thái đã được người dùng cập nhật.

## Số lượng được bổ sung

| Danh sách | Dữ liệu demo |
| --- | --- |
| Cơ sở | 20 đang hoạt động, 1 ngừng hoạt động, 1 bảo trì |
| Loại ngăn kho | 20 loại có đủ kích thước dài × rộng × cao, diện tích dài × rộng, giá và ảnh |
| Ngăn kho | Mỗi cơ sở demo có 20 ngăn; mỗi cơ sở gốc thêm 20 ngăn trống và ngăn riêng cho từng đơn |
| Khách hàng | 20 tài khoản mới, có ví dụ tài khoản bị vô hiệu hóa |
| Gán quản lý | 20 quản lý chưa được gán và 22 quản lý đã có cơ sở demo |
| Gán nhân viên | 20 nhân viên chưa gán; mỗi cơ sở gốc thêm 20 nhân viên đã gán |
| Đơn thuê / hợp đồng | Mỗi cơ sở gốc: 20 đang thuê, 20 chờ nhận, 20 hoàn tất, 20 đã hủy |
| Chờ thanh toán | 20 đơn tại HCM-D1, mỗi khách chỉ có 1 đơn thanh toán sau chưa trả tiền |
| Yêu cầu hoàn tiền | 40 mỗi cơ sở gốc, phủ đủ 8 trạng thái xử lý |
| Hỗ trợ | 20 mỗi cơ sở gốc, phủ đủ trạng thái, danh mục và mức ưu tiên |
| Thanh toán | Đầy đủ các trạng thái chờ, thành công, thất bại, chờ hoàn và đã hoàn |
| Bàn giao | 20 biên bản nhận kho đang thuê và 40 biên bản nhận/trả kho hoàn tất mỗi cơ sở gốc |
| Lịch công việc | 20 lịch nhận kho hôm nay mỗi cơ sở gốc, cùng ví dụ trả kho / quá hạn |
| Thông báo, lịch sử đăng nhập | Ít nhất 20 cho khách hàng mặc định, quản lý từng cơ sở, staff phụ trách, admin và business |
| Nhật ký nghiệp vụ | 20 thao tác bàn giao mỗi cơ sở gốc |

Các cơ sở gốc là `HCM-D1`, `HCM-D7`, `HCM-TD`. Khách mặc định
`customer@gmail.com` thấy các đơn demo ở cả ba cơ sở. Staff đã được gán cho
cơ sở được ưu tiên làm người bàn giao; nếu chưa có thì seed tạo staff demo.
Không tạo vai trò/quyền giả hoặc dữ liệu danh sách chờ đã bỏ khỏi giao diện.

## Tình huống nghiệp vụ

- Đơn đã thanh toán nhưng chưa nhận kho: đã/chưa xác nhận ngăn, có/chưa gán staff,
  sự cố bàn giao ở đủ trạng thái.
- Đang thuê: bình thường, chờ gia hạn, yêu cầu trả, quá hạn, khóa truy cập,
  chờ/đã niêm phong. Mỗi đơn đang sử dụng một ngăn riêng.
- Hủy trong 24 giờ hoàn cọc theo tỷ lệ trong 24 giờ; sau 24 giờ dùng tỷ lệ sau
  24 giờ đã chụp lại từ chính sách cơ sở. Hoàn 100% khoản thu tiền thuê (bao gồm
  phí dịch vụ trả trước), khớp luồng hủy hiện tại. Ví dụ hủy do lỗi bàn giao của
  cơ sở được hoàn toàn bộ tiền cọc và khoản thu tiền thuê.
- Trả kho: nguyên vẹn hoặc khấu trừ 50.000 đ sửa khóa, có biên bản tương ứng.
- Hoàn xong: có thời điểm, mã chuyển khoản và số dư cọc bằng 0.
- Hợp đồng có đầy đủ nội dung điều khoản, hàng cấm, thời điểm xác nhận, phiên bản,
  mã kiểm tra và ảnh hợp đồng mẫu cho đơn đã bàn giao.

Ngày tạo được phân bố khác nhau để kiểm tra thứ tự mới nhất và chuyển trang.
Các trường chưa phát sinh **giữ NULL đúng nghiệp vụ**: PIN trước bàn giao,
ngày trả trước khi trả kho, ngày hoàn khi chưa hoàn, thời điểm đọc thông báo
chưa đọc, ghi chú giải quyết khi ticket chưa được giải quyết, thông tin cổng
thanh toán bị thiếu ở trạng thái `MISSING_METADATA`.

## Cấu hình và nhận biết

- Đơn/cơ sở: tiền tố `DEMO-PG-`; ngăn và tài khoản: `PG-` / `pg_`.
- Tài khoản mới dùng email `@example.test`, mật khẩu từ cấu hình `SEED_*_PASSWORD`
  tương ứng. PIN mẫu của các đơn đã bàn giao là `123456`, lưu dạng băm.
- `SEED_PAGINATION_ENABLED=false` tắt việc bổ sung bộ demo. Không tự xóa dữ liệu đã tạo.
- Seed nằm trong luồng `seed.users.enabled`; profile production hiện tắt luồng này.
- Ảnh hợp đồng PNG mẫu được đóng gói sẵn, ghi rõ không có giá trị giao dịch.
  `SEED_DEMO_BASE_URL` mặc định `http://10.0.2.2:8080` cho Android emulator;
  đặt URL backend phù hợp **trước lần seed đầu** nếu dùng điện thoại thật/web.
  Ảnh kho và avatar dùng URL mẫu bên ngoài, cần có mạng để tải.
- Bộ hoàn tiền có metadata mô phỏng. Tiến trình gửi/đối soát hoàn tiền loại bỏ
  đơn `DEMO-PG-` **trước giới hạn 20** và khi đọc lại từng đơn; không gọi VNPay
  cho các khoản hoàn này, kể cả bấm đối soát thủ công hoặc thử lại yêu cầu.
  Đơn chờ/thất bại không có metadata cổng để không bị tiến trình đối soát thanh toán xử lý.
- Đơn thanh toán sau vẫn hết hạn theo luồng thật; seed không đặt lại hạn khi khởi động lại.
