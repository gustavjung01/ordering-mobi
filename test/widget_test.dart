import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/app/app.dart';

void main() {
  testWidgets('renders ordering navigation shell', (tester) async {
    await tester.pumpWidget(const OrderingApp());

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
