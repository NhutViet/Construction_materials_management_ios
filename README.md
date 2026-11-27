# Construction Materials — iOS app (SwiftUI)

App iOS native cho hệ thống quản lý vật liệu xây dựng, dùng chung backend Supabase với bản web.

## Phạm vi hiện tại

- Đăng nhập bằng username/email + mật khẩu
- Tổng quan: doanh thu, công nợ, số hóa đơn, vật liệu tồn kho thấp, đơn gần đây
- Danh sách hóa đơn + tìm kiếm + lọc trạng thái
- Tạo hóa đơn nhiều mặt hàng, giảm giá, thuế, thanh toán trước
- Chi tiết hóa đơn:
  - thông tin khách hàng, thanh toán
  - danh sách mặt hàng dạng card
  - công tắc **Chốt giá** từng mặt hàng
  - giao hàng từng phần / giao hết
  - lịch sử giao hàng theo hóa đơn
- Sửa hóa đơn (giữ số lượng đã giao, không cho giảm dưới mức đã giao)
- Hủy hóa đơn
- Ghi nhận thanh toán từng lần
- Tab **Lịch sử giao hàng** toàn bộ
- Hàng hoá: xem, tìm kiếm, thêm/sửa vật tư
- Tab **Cá nhân**: hồ sơ, thông tin liên hệ/ngân hàng, sửa hồ sơ, đăng xuất
- Menu trái cho các trang phụ: Khách hàng, Nhập hàng, Báo cáo doanh thu
- Nhập hàng: tạo phiếu nhập, cộng tồn kho, theo dõi công nợ nhà cung cấp
- Khách hàng: tổng hợp theo SĐT, công nợ, danh sách hóa đơn
- Báo cáo doanh thu: 6 tháng gần đây, top vật tư, tình trạng thanh toán

Các phần làm sau: tra cứu hóa đơn công khai, thông báo đẩy, app icon, xuất PDF.

## Yêu cầu

- macOS có **Xcode 27+** (dùng **Device Hub**, không cần Simulator.app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Tài khoản Supabase hiện tại

## Chạy app

```bash
xcodegen generate
open ConstructionMaterials.xcodeproj
```

Trong Xcode:

1. Chọn target **ConstructionMaterials**
2. Tab **Signing & Capabilities** → chọn Apple Developer Team (nếu chạy trên iPhone thật)
3. Chọn simulator iPhone hoặc iPhone thật
4. Run (⌘R)

Nếu chỉ chạy simulator thì không cần team.

## Cấu hình Supabase

File `Config/Secrets.xcconfig` đang trỏ tới project Supabase hiện tại:

```xcconfig
SUPABASE_URL = https:/$()/ivphlgjgazimmihaifrs.supabase.co
SUPABASE_ANON_KEY = sb_publishable_...
```

`$()` là cách viết `//` trong xcconfig để không bị coi là comment.

Nếu đổi project, sửa file này hoặc copy từ `Config/Secrets.example.xcconfig`.

## Tài khoản test

```text
Username: viet3557
Password: 123456789
```

App tự tìm email từ bảng `profiles` theo username rồi đăng nhập Supabase Auth.

## Cấu trúc code

```text
  Config/                 # xcconfig + Supabase keys
  project.yml             # XcodeGen project definition
  ConstructionMaterials/
    App/                  # entry point, root view
    Core/                 # config, Supabase, theme, formatters
    Models/               # Profile, Material, Invoice, DeliveryRecord, StockIn
    Services/             # Auth, Invoice, Material, StockIn
    Stores/               # AuthStore
    Features/
      Auth/               # Login
      Dashboard/          # Tổng quan
      Orders/             # Danh sách, tạo/sửa, chi tiết, giao hàng, thanh toán
      Inventory/          # Hàng hoá + form thêm/sửa vật tư
      StockIn/            # Phiếu nhập hàng
      Customers/          # Danh sách + chi tiết khách hàng
      Revenue/            # Báo cáo doanh thu
      DeliveryHistory/    # Tab lịch sử giao hàng
      Profile/            # Tab cá nhân + sửa hồ sơ
      Root/               # Tab bar, menu trái (side menu)
    Shared/               # Component dùng chung
```

## Ghi chú kỹ thuật

- Supabase Swift SDK phiên bản `2.55.x` (stable v2), không dùng v3 alpha.
- Session được Supabase SDK lưu trong Keychain.
- Giao hàng cập nhật:
  - `deliveredQuantity`, `deliveredAmount`, `totalPrice`
  - tổng tiền hóa đơn + trạng thái thanh toán
  - bảng `delivery_records` theo `batchId`
  - tồn kho vật tư (chỉ với hóa đơn mới có `stockDeductedAtCreation = false`)
- Chốt giá: bật → giữ giá gốc; tắt → áp lại giá vật tư hiện tại cho phần còn lại.
- Khi sửa giá vật tư: phần đã giao giữ nguyên giá/thành tiền, chỉ phần còn lại nhận giá mới; mặt hàng đang chốt giá được bỏ qua.
- Tồn kho chỉ trừ khi ghi nhận giao hàng; phiếu nhập hàng cộng tồn kho ngay khi lưu.
