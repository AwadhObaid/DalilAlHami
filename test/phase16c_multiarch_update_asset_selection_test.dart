import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/app_update_service.dart';

void main() {
  group('Phase 16C multi-architecture update asset selection', () {
    test('prefers Universal APK even when another APK appears first', () {
      final release = AppGitHubRelease.tryFromJson({
        'tag_name': 'v1.0.10',
        'name': 'Dalil Al Hami v1.0.10 Stable',
        'html_url': 'https://example.test/releases/v1.0.10',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'DalilAlHami-v1.0.10-arm64-v8a.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-arm64-v8a.apk',
          },
          {
            'name': 'DalilAlHami-v1.0.10-armeabi-v7a.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-armeabi-v7a.apk',
          },
          {
            'name': 'DalilAlHami-v1.0.10-universal.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-universal.apk',
          },
          {
            'name': 'DalilAlHami-v1.0.10-x86_64.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-x86_64.apk',
          },
        ],
      });

      expect(release, isNotNull);
      expect(
        release!.preferredDownloadUri.toString(),
        'https://example.test/DalilAlHami-v1.0.10-universal.apk',
      );
    });

    test('falls back to first APK for legacy single-architecture releases', () {
      final release = AppGitHubRelease.tryFromJson({
        'tag_name': 'v1.0.9',
        'name': 'Dalil Al Hami v1.0.9 Stable',
        'html_url': 'https://example.test/releases/v1.0.9',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'DalilAlHami-v1.0.9.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.9.apk',
          },
        ],
      });

      expect(release, isNotNull);
      expect(
        release!.preferredDownloadUri.toString(),
        'https://example.test/DalilAlHami-v1.0.9.apk',
      );
    });

    test('ignores SHA files and non-APK assets', () {
      final release = AppGitHubRelease.tryFromJson({
        'tag_name': 'v1.0.10',
        'name': 'Dalil Al Hami v1.0.10 Stable',
        'html_url': 'https://example.test/releases/v1.0.10',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'SHA256SUMS.txt',
            'browser_download_url': 'https://example.test/SHA256SUMS.txt',
          },
          {
            'name': 'DalilAlHami-v1.0.10-universal.apk.sha256.txt',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-universal.apk.sha256.txt',
          },
          {
            'name': 'DalilAlHami-v1.0.10-universal.apk',
            'browser_download_url':
                'https://example.test/DalilAlHami-v1.0.10-universal.apk',
          },
        ],
      });

      expect(release, isNotNull);
      expect(
        release!.preferredDownloadUri.toString(),
        'https://example.test/DalilAlHami-v1.0.10-universal.apk',
      );
    });
  });
}
