# Cấu hình bản phát hành

## Dịch vụ bản đồ

Bản local mặc định dùng tile công cộng OpenStreetMap để phát triển. Khi phát
hành cho người dùng thật, cấu hình một nhà cung cấp tile có hạn mức và điều
khoản phù hợp; không sửa URL riêng lẻ trong từng màn hình.

```powershell
flutter build web --release `
  --dart-define=API_BASE_URL="https://api.example.com/api" `
  --dart-define=MAP_TILE_URL="https://tiles.example.com/{z}/{x}/{y}.png" `
  --dart-define=MAP_ATTRIBUTION_TEXT="Tên nhà cung cấp" `
  --dart-define=MAP_ATTRIBUTION_URL="https://example.com/map-terms" `
  --dart-define=MAP_USER_AGENT_PACKAGE="vn.example.greencycle"
```

`API_BASE_URL` phải trỏ tới public HTTPS endpoint có hậu tố `/api`. Nếu bỏ qua
trên web release, app dùng `/api` cùng origin; mobile release sẽ dừng sớm để
không vô tình phát hành bản gọi localhost. Realtime tự chuyển endpoint này sang
`wss://.../ws/realtime`. Bản release không đọc địa chỉ server từng lưu từ màn
debug, tránh mang cấu hình localhost sang máy người dùng.

Các biến trên áp dụng đồng nhất cho bản đồ chọn địa chỉ, hành trình báo cáo và
lộ trình của nhân viên thu gom. Nội dung ghi nguồn luôn hiển thị trên bản đồ và
mở trang điều khoản của nhà cung cấp.

Trước khi phát hành mobile, thay bundle/application ID `com.example.*` bằng ID
chính thức và đăng ký lại cấu hình Firebase tương ứng. Không đổi riêng package
ID nếu chưa cập nhật ứng dụng Firebase, vì upload ảnh sẽ ngừng hoạt động.
