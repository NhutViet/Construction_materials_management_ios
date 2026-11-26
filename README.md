# Construction Materials — iOS app (SwiftUI)

App iOS native cho hệ thống quản lý vật liệu xây dựng, dùng chung backend Supabase với bản web.

## Phạm vi hiện tại (MVP)

- Đăng nhập bằng username/email + mật khẩu
- Tổng quan: doanh thu, công nợ, số hóa đơn, vật liệu tồn kho thấp, đơn gần đây
- Danh sách hóa đơn + tìm kiếm + lọc trạng thái
- Chi tiết hóa đơn:
  - thông tin khách hàng, thanh toán
  - danh sách mặt hàng dạng card
  - công tắc **Chốt giá** từng mặt hàng
  - giao hàng từng phần / giao hết
  - lịch sử giao hàng theo hóa đơn
- Lịch sử giao hàng toàn bộ
- Danh sách hàng hoá (xem, tìm kiếm)
- Hồ sơ người dùng + đăng xuất

Các phần làm sau: tạo/sửa hóa đơn, thêm/sửa vật tư, nhập hàng, khách hàng, doanh thu nâng cao, phân tích, tra cứu hóa đơn công khai.

## Yêu cầu

- macOS có **Xcode 16.4+** (máy hiện tại chưa cài Xcode, chỉ có Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Tài khoản Supabase hiện tại

## Chạy app

```bash
cd mobile-ios
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
mobile-ios/
  Config/                 # xcconfig + Supabase keys
  project.yml             # XcodeGen project definition
  ConstructionMaterials/
    App/                  # entry point, root view
    Core/                 # config, Supabase, theme, formatters
    Models/               # Profile, Material, Invoice, DeliveryRecord
    Services/             # Auth, Invoice, Delivery, Material
    Stores/               # AuthStore
    Features/
      Auth/               # Login
      Dashboard/          # Tổng quan
      Orders/             # Danh sách, chi tiết, giao hàng, lịch sử
      Inventory/          # Hàng hoá
      More/               # Hồ sơ, lịch sử giao hàng, đăng xuất
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
