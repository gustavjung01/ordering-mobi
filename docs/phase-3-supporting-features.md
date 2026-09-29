# Lô 3 — Supporting features parity

## Phạm vi đã triển khai

| PWA behavior | Backend/API contract | Flutter implementation | Verification |
| --- | --- | --- | --- |
| Kiểm tra lifecycle điểm bán trước khi mở đặt hàng | `GET /api/customer-portal/registrations/current` | Session gate kiểm lifecycle trước `/me`; chỉ `active_customer` được vào luồng đặt hàng | API contract test + CI |
| Đăng ký điểm bán | `POST /api/customer-portal/registrations` + `Idempotency-Key` | Form Tài khoản, canonical idempotency, pending key trong secure storage | API + retry-after-restart test |
| Bổ sung đăng ký | `POST /api/customer-portal/registrations/{id}/resubmit` + `expectedVersion` | Dùng version hiện tại, cùng canonical retry contract | API contract test |
| Xem trạng thái và ghi chú xử lý | Lifecycle snapshot + `reviewReason` | Tài khoản hiển thị trạng thái thực và cho tải lại | Widget compile gate |
| Cập nhật điểm bán đang hoạt động | `PATCH /api/customer-portal/me` + optimistic timestamps + `Idempotency-Key` | Chỉnh tên điểm bán, điện thoại và địa chỉ; conflict 409 tải lại dữ liệu Công Ty trước khi gửi lại | API contract test |
| Hỏi Hưng Phát | `POST /api/assistant/chat` qua PWA BFF, Clerk bearer token | Trợ lý native, tối đa 1.000 ký tự, hiển thị hạn mức, advisory-only | Assistant API test |
| Cart/checkout draft khi mất mạng | Local persistence theo user | Giữ cơ chế Lô 2; không tạo cache riêng cho dữ liệu Công Ty | Existing repository tests |

## Ranh giới chưa được giả lập production

### Tin tức / inbox / tùy chọn thông báo

PWA production hiện vẫn chuyển các hàm sau sang mock/local adapter:

- `listAnnouncements()`
- `getAnnouncementById()`
- `markAnnouncementRead()`
- `getNotificationPreference()`
- `saveNotificationPreference()`

Vì chưa có Customer API production tương ứng, mobile không dựng dữ liệu mẫu để che khoảng trống backend.

### Push notification

OneSignal trên PWA hiện là kênh browser push. Inbox nghiệp vụ vẫn cần backend Công Ty làm nguồn sự thật. Android push chỉ nên nối khi contract inbox/preferences và backend sender/outbox đã sẵn sàng.

### Vị trí GPS trong hồ sơ

Customer Portal cho phép `locationUrl` là field tùy chọn khi người dùng chủ động lấy vị trí. Mobile không tự thêm SDK định vị trong lô này. Khi không có vị trí mới, payload profile không gửi `locationUrl`, tránh ghi đè dữ liệu vị trí hiện hữu.

## Không thuộc lô này

- production release;
- production signing identity;
- publish R2;
- thay đổi backend/database production.
