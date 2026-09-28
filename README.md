# Ordering Mobile

Ứng dụng Flutter Android native cho Customer Ordering Hưng Phát.

## Nguồn sự thật

- Nghiệp vụ phải parity 100% với Customer Ordering PWA trong `binhnxwjfjxm/nguyenlieuhungphat/customer-ordering/**`.
- UI/UX có thể tối ưu native nhưng không được thay đổi business rule, contract, validation hoặc trạng thái nghiệp vụ.
- Issue #1 là bootstrap/release contract chính.

## Workflow

```text
main -> agent/<task> -> CI -> review -> merge khi được yêu cầu
```

Không publish APK, thay signing identity, thay release contract hoặc đẩy R2 ngoài một operation phát hành được yêu cầu rõ.
