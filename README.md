# Ordering Mobile

Ứng dụng Flutter Android native cho Customer Ordering Hưng Phát.

## Nguồn sự thật nghiệp vụ

Ordering Mobile phải parity 100% với Customer Ordering PWA tại repo `binhnxwjfjxm/nguyenlieuhungphat`, phạm vi `customer-ordering/**`.

UI/UX mobile được phép thiết kế native và chuyên nghiệp hơn, nhưng không được tự thay đổi business rule, validation, contract API, order status, cart/checkout semantics hoặc quyền thao tác.

Mỗi feature phải được nghiệm thu theo chuỗi:

~~~text
PWA behavior
-> API/backend contract thực tế
-> Flutter implementation
-> test/verification parity
~~~

Issue #1 là nguồn bàn giao bootstrap và release contract.

## Môi trường chuẩn

- Flutter 3.47.2
- Java 17
- Android là nền tảng phát hành hiện tại
- Không WebView làm ứng dụng chính
- Không database credential, server secret hoặc private API key trong APK

## Runtime của installation Hưng Phát

Ordering Mobile là app dành cho khách hàng cuối nên installation được cấu hình sẵn trong APK. Người dùng không nhập địa chỉ hệ thống.

~~~text
Ordering Mobile
├── Clerk publishable key -> cấu hình public của installation
├── Customer Portal API   -> https://40.233.83.234/api/customer-portal/**
└── Hỏi Hưng Phát         -> https://sales.nguyenlieuhungphat.com/api/assistant/chat
~~~

Catalog, hồ sơ, đăng ký điểm bán và đơn hàng gọi trực tiếp Customer Portal API trên VPS Công Ty bằng Clerk bearer token. Mobile không kết nối PostgreSQL và không chứa `DATABASE_URL`, Clerk secret, token máy chủ hoặc API key nội bộ.

Trợ lý giữ boundary riêng qua Customer Ordering BFF vì BFF sở hữu server-side AI token/context. Không đưa `ORDERING_AI_API_TOKEN` vào APK.

Clerk publishable key là cấu hình công khai dành cho client. Backend Công Ty xác minh token theo Clerk issuer/JWKS; secret xác thực không nằm trong mobile.

## Chạy local

Lấy dependencies:

~~~powershell
flutter pub get
~~~

Installation Hưng Phát đã có cấu hình mặc định nên chạy thẳng:

~~~powershell
flutter run -d emulator-5556
~~~

Để build một installation khác từ cùng codebase, có thể override public runtime config:

~~~powershell
flutter run -d emulator-5556 `
  --dart-define=ORDERING_CLERK_PUBLISHABLE_KEY=pk_live_REPLACE_WITH_PUBLIC_KEY `
  --dart-define=ORDERING_CUSTOMER_PORTAL_ORIGIN=https://REPLACE_WITH_COMPANY_API_HOST `
  --dart-define=ORDERING_ASSISTANT_ORIGIN=https://REPLACE_WITH_CUSTOMER_ORDERING_HOST
~~~

Trạng thái Clerk được lưu qua `flutter_secure_storage`. Ứng dụng không duy trì một bản raw access token riêng; token gửi Customer Portal được lấy từ phiên Clerk đang hoạt động để tránh hai nguồn session.

Kiểm tra trước khi merge:

~~~powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
~~~

## Release contract với Key Manager

~~~text
Version file: release-config.json
Version field: version
Build script: scripts\build-release.ps1
Build output: dist\android-release
APK: Ordering-<version>.apk
AAB: Ordering-<version>.aab
Manifest: latest.json
R2 bucket: hung-phat-app
R2 prefix: ordering
Public update base:
https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering
~~~

Source folder trên máy phát hành:

~~~text
F:\1_A_Disk_D\Hung-Phat\ordering-mobi-app\androi
~~~

Cấu hình Key Manager:

~~~text
Source folder:
F:\1_A_Disk_D\Hung-Phat\ordering-mobi-app\androi

Build output:
dist\android-release

Version file:
release-config.json

Version field:
version

Artifact patterns:
Ordering-*.apk
Ordering-*.aab
latest.json

Manifest/publish pointer:
latest.json

R2 bucket:
hung-phat-app

R2 prefix:
ordering
~~~

Build command chuẩn:

~~~powershell
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 -UpdateBaseUrl "https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering"
~~~

Key Manager truyền `KM_RELEASE_VERSION` và `KM_RELEASE_NOTES`.

### Signing production

Ordering dùng signing identity riêng, không dùng signing identity lịch sử của MCP.

~~~text
ORDERING_ANDROID_KEYSTORE
ORDERING_ANDROID_KEYSTORE_PASSWORD
ORDERING_ANDROID_KEY_ALIAS
ORDERING_ANDROID_KEY_PASSWORD
~~~

Không commit keystore hoặc password. Sau bản public đầu tiên, signing identity là compatibility contract.

CI có thể dùng `ORDERING_CI_RELEASE_VALIDATION=true` để kiểm compile release bằng debug signing. Artifact đó tuyệt đối không được phát hành.

## Public publication verification

~~~powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-release-publication.ps1 `
  -UpdateBaseUrl "https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering"
~~~

Chỉ coi release hoàn chỉnh khi `latest.json` truy cập công khai được, APK tải được và SHA-256 khớp.

## Git workflow

~~~text
main
-> agent/<task>
-> code/test
-> CI
-> review
-> merge khi được yêu cầu rõ
-> local pull exact main
-> build/release là operation riêng
~~~
