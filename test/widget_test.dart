import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/app/app.dart';
import 'package:ordering_mobile/app/navigation/app_shell.dart';
import 'package:ordering_mobile/core/config/runtime_config.dart';

void main() {
  testWidgets('blocks protected app when login configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const OrderingApp(
        runtimeConfig: OrderingRuntimeConfig(
          clerkPublishableKey: '',
          customerPortalOrigin: '',
        ),
      ),
    );

    expect(find.text('Hưng Phát Đặt Hàng'), findsOneWidget);
    expect(
      find.text(
        'Ứng dụng chưa được cấu hình đăng nhập. '
        'Vui lòng liên hệ bộ phận phụ trách.',
      ),
      findsOneWidget,
    );
    expect(find.text('Trang chủ'), findsNothing);
  });

  testWidgets('renders ordering navigation shell after authentication', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const AppShell(),
        theme: ThemeData(useMaterial3: true),
      ),
    );

    expect(find.text('Hưng Phát Đặt Hàng'), findsWidgets);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Sản phẩm'), findsOneWidget);
    expect(find.text('Đặt nhanh'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);

    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
  });
}
