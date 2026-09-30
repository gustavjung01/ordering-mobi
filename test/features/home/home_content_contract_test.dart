import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/network/customer_portal_models.dart';

void main() {
  test('CustomerHomeContent parse đúng contract Công Ty', () {
    final content = CustomerHomeContent.fromJson({
      'sectionTitle': 'Sự kiện',
      'programContent': 'Ưu đãi dành cho khách đặt hàng trong tháng này.',
      'visible': true,
      'bannerUrl': 'https://example.test/banner.webp?v=2',
      'imagePresent': true,
      'updatedAt': '2026-09-29T12:00:00.000Z',
    });

    expect(content.sectionTitle, 'Sự kiện');
    expect(content.programContent, contains('Ưu đãi'));
    expect(content.visible, isTrue);
    expect(content.imagePresent, isTrue);
    expect(content.bannerUrl, contains('banner.webp'));
  });

  test('CustomerHomeContent tương thích payload cũ chưa có nội dung chương trình', () {
    final content = CustomerHomeContent.fromJson({
      'sectionTitle': 'Sự kiện',
      'visible': true,
      'bannerUrl': 'https://example.test/banner.webp?v=2',
      'imagePresent': true,
      'updatedAt': '2026-09-29T12:00:00.000Z',
    });

    expect(content.programContent, isEmpty);
  });

  test('Trang chủ có đủ sáu ảnh ngành hàng và không còn card sản phẩm', () {
    final source = File(
      'lib/features/home/presentation/home_screen.dart',
    ).readAsStringSync();

    for (final asset in [
      'icon-tra-sua.webp',
      'icon-mi-cay.webp',
      'icon-dong-lanh.webp',
      'icon-an-vat.webp',
      'icon-bao-bi.webp',
      'icon-gia-vi.webp',
    ]) {
      expect(source, contains(asset));
    }
    expect(source, contains('_ManagedHomeBanner'));
    expect(source, contains('_openEventDetails'));
    expect(source, contains('showModalBottomSheet<void>'));
    expect(source, contains("Key('event-detail-sheet')"));
    expect(source, contains("Key('event-detail-content')"));
    expect(source, contains("Key('managed-event-banner')"));
    expect(source, contains('content.programContent'));
    expect(source, isNot(contains('_ProductPreviewCard')));
    expect(source, isNot(contains('CatalogProductVisual')));
  });
}
