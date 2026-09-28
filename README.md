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

## Chạy local

Lấy dependencies:

~~~powershell
flutter pub get
~~~

Auth/API foundation dùng đúng public Clerk publishable key và public origin của Customer Ordering PWA. Mobile gọi Customer Portal BFF tại `/api/customer-portal/**`; không gọi thẳng API Công Ty và không chứa server token.

~~~powershell
flutter run -d emulator-5556 `
  --dart-define=ORDERING_CLERK_PUBLISHABLE_KEY=pk_test_REPLACE_WITH_PUBLIC_KEY `
  --dart-define=ORDERING_CUSTOMER_PORTAL_ORIGIN=https://REPLACE_WITH_CUSTOMER_ORDERING_HOST
~~~

`ORDERING_CLERK_PUBLISHABLE_KEY` là publishable key dành cho client. Không đưa `CLERK_SECRET_KEY`, database credential, token máy chủ hoặc API key nội bộ vào source, APK hay lệnh được lưu trong repo.

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
