import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ordering_mobile/core/update/app_update_service.dart';
import 'package:ordering_mobile/features/account/presentation/app_update_card.dart';

class _FakeUpdatePlatform implements AppUpdatePlatform {
  bool installAllowed = false;
  bool openedSettings = false;
  int installs = 0;

  @override
  Future<String> currentVersion() async => '1.0.0';

  @override
  Future<bool> supportsDirectInstall() async => true;

  @override
  Future<bool> canInstallPackages() async => installAllowed;

  @override
  Future<void> openInstallPermissionSettings() async {
    openedSettings = true;
  }

  @override
  Future<void> downloadAndInstall({
    required Uri url,
    required String sha256,
  }) async {
    installs += 1;
  }
}

void main() {
  testWidgets(
    'Tài khoản kiểm tra bản mới và cài lại sau khi cấp quyền Android',
    (tester) async {
      final platform = _FakeUpdatePlatform();
      final service = AppUpdateService(
        baseUrl: 'https://updates.example.vn/ordering',
        platform: platform,
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'version': '1.0.1',
                'apk': 'Ordering-1.0.1.apk',
                'url': 'https://updates.example.vn/ordering/Ordering-1.0.1.apk',
                'size': 1048576,
                'sha256': 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
                'releaseNotes': 'Cải thiện trải nghiệm đặt hàng.',
              }),
            ),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppUpdateCard(updateService: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cập nhật ứng dụng'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.byKey(const Key('check-update-button')), findsOneWidget);
      expect(find.byKey(const Key('update-install-guide')), findsOneWidget);
      expect(find.textContaining('Hưng Phát Đặt Hàng'), findsWidgets);

      await tester.tap(find.byKey(const Key('check-update-button')));
      await tester.pumpAndSettle();

      expect(find.text('Có bản 1.0.1 mới.'), findsOneWidget);
      expect(find.text('Bản phát hành'), findsOneWidget);
      expect(find.text('1.0 MB'), findsOneWidget);
      expect(find.byKey(const Key('install-update-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('install-update-button')));
      await tester.pumpAndSettle();

      expect(platform.openedSettings, isTrue);
      expect(platform.installs, 0);
      expect(
        find.textContaining('Bật “Cho phép từ nguồn này”'),
        findsOneWidget,
      );

      platform.installAllowed = true;
      await tester.tap(find.byKey(const Key('install-update-button')));
      await tester.pumpAndSettle();

      expect(platform.installs, 1);
      expect(
        find.text(
          'Đã tải và kiểm tra gói cập nhật. Android đang mở màn hình cài đặt.',
        ),
        findsOneWidget,
      );
    },
  );

  test('AccountScreen hiển thị card cập nhật trong mục Tài khoản', () {
    final source = File(
      'lib/features/account/presentation/account_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import 'app_update_card.dart';"));
    expect(source, contains('const AppUpdateCard()'));
  });
}
