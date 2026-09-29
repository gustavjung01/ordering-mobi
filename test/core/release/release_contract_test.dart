import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const canonicalUpdateBase =
      'https://pub-381648426a2447a7a5edd970ca02d14e.r2.dev/ordering';

  test('metadata version name stays synchronized for Key Manager', () {
    final releaseConfig = jsonDecode(
      File('release-config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final releaseVersion = releaseConfig['version']?.toString();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(releaseVersion, matches(r'^\d+\.\d+\.\d+$'));
    expect(match, isNotNull);
    expect(match!.group(1), releaseVersion);
  });

  test('build script matches the Ordering Key Manager package contract', () {
    final source = File('scripts/build-release.ps1').readAsStringSync();

    for (final required in [
      'KM_RELEASE_VERSION',
      'KM_RELEASE_NOTES',
      'ORDERING_ANDROID_KEYSTORE',
      'ORDERING_ANDROID_KEYSTORE_PASSWORD',
      'ORDERING_ANDROID_KEY_ALIAS',
      'ORDERING_ANDROID_KEY_PASSWORD',
      'ORDERING_CI_RELEASE_VALIDATION',
      canonicalUpdateBase,
      r'dist\android-release',
      r'Ordering-$version.apk',
      r'Ordering-$version.aab',
      'latest.json',
      'flutter build apk --release',
      'flutter build appbundle --release',
      'pubspec.yaml version',
    ]) {
      expect(source, contains(required), reason: required);
    }
  });

  test('publication verifier locks the public pointer and APK location', () {
    final source = File('scripts/verify-release-publication.ps1')
        .readAsStringSync();

    for (final required in [
      canonicalUpdateBase,
      'latest.json',
      r'Ordering-$version.apk',
      'Get-FileHash',
      'SHA256',
      'Published APK URL must point to',
    ]) {
      expect(source, contains(required), reason: required);
    }
  });

  test('Android package and production signing variables stay canonical', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('applicationId = "com.hungphat.ordering"'));
    expect(gradle, contains('namespace = "com.hungphat.ordering"'));
    for (final required in [
      'ORDERING_ANDROID_KEYSTORE',
      'ORDERING_ANDROID_KEYSTORE_PASSWORD',
      'ORDERING_ANDROID_KEY_ALIAS',
      'ORDERING_ANDROID_KEY_PASSWORD',
    ]) {
      expect(gradle, contains(required), reason: required);
    }
    expect(
      gradle,
      contains('ORDERING_CI_RELEASE_VALIDATION'),
    );
  });

  test('keystore material cannot be committed by normal Git workflow', () {
    final ignore = File('.gitignore').readAsStringSync();

    expect(ignore, contains('*.jks'));
    expect(ignore, contains('*.keystore'));
    expect(ignore, contains('key.properties'));
  });

  test('README keeps the external Key Manager upload profile canonical', () {
    final readme = File('README.md').readAsStringSync();

    for (final required in [
      r'dist\android-release',
      'Ordering-*.apk',
      'Ordering-*.aab',
      'latest.json',
      'hung-phat-app',
      'R2 prefix:',
      'ordering',
      canonicalUpdateBase,
    ]) {
      expect(readme, contains(required), reason: required);
    }
  });
}
