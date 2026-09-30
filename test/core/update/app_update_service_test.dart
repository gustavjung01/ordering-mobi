import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/update/app_update_service.dart';

void main() {
  group('compareAppVersions', () {
    test('compares semantic versions', () {
      expect(compareAppVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareAppVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareAppVersions('2.0.0', '2.0.0'), 0);
    });

    test('rejects non-strict versions', () {
      expect(
        () => compareAppVersions('1.0', '1.0.0'),
        throwsA(isA<AppUpdateFailure>()),
      );
    });
  });

  test('manifest requires https', () {
    final hash = List.filled(64, '0').join();
    expect(
      () => AppReleaseManifest.fromJson(
        {
          'version': '1.0.0',
          'url': 'http://example.test/Ordering-1.0.0.apk',
          'sha256': hash,
        },
        baseUri: Uri.parse('https://example.test/ordering/'),
      ),
      throwsA(isA<AppUpdateFailure>()),
    );
  });

  test('manifest rejects APK outside configured update base', () {
    final hash = List.filled(64, '0').join();
    expect(
      () => AppReleaseManifest.fromJson(
        {
          'version': '1.0.0',
          'url': 'https://cdn.example.test/Ordering-1.0.0.apk',
          'sha256': hash,
        },
        baseUri: Uri.parse('https://example.test/ordering/'),
      ),
      throwsA(isA<AppUpdateFailure>()),
    );
  });

  test('manifest accepts APK under configured update base', () {
    final hash = List.filled(64, '0').join();
    final manifest = AppReleaseManifest.fromJson(
      {
        'version': '1.0.0',
        'url': 'https://example.test/ordering/Ordering-1.0.0.apk',
        'sha256': hash,
      },
      baseUri: Uri.parse('https://example.test/ordering/'),
    );

    expect(
      manifest.downloadUrl,
      Uri.parse('https://example.test/ordering/Ordering-1.0.0.apk'),
    );
  });
}
