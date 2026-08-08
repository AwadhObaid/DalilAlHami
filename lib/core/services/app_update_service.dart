import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const String repositoryOwner = 'AwadhObaid';
  static const String repositoryName = 'DalilAlHami-Releases';
  static const Duration requestTimeout = Duration(seconds: 12);

  final http.Client _client;

  Uri get _releasesUri => Uri.https(
        'api.github.com',
        '/repos/$repositoryOwner/$repositoryName/releases',
        const <String, String>{'per_page': '20'},
      );

  Future<String> currentVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return _packageVersionLabel(info);
  }

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final current = AppSemanticVersion.tryParse(packageInfo.version);
    if (current == null) {
      throw const AppUpdateException(
        'The installed application version could not be parsed.',
      );
    }

    final response = await _client.get(
      _releasesUri,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'DalilAlHami-Android',
      },
    ).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw AppUpdateException(
        'GitHub update check failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const AppUpdateException(
        'GitHub returned an unexpected release response.',
      );
    }

    // Beta builds can move to newer beta or stable releases. Stable builds
    // intentionally ignore prereleases so public users never receive beta
    // updates unless the installed app itself is a prerelease build.
    final allowPrereleases = current.isPrerelease;
    AppGitHubRelease? newestEligible;

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final release = AppGitHubRelease.tryFromJson(item);
      if (release == null || release.isDraft) {
        continue;
      }
      if (release.isPrerelease && !allowPrereleases) {
        continue;
      }
      if (release.version.compareTo(current) <= 0) {
        continue;
      }
      if (newestEligible == null ||
          release.version.compareTo(newestEligible.version) > 0) {
        newestEligible = release;
      }
    }

    return AppUpdateCheckResult(
      currentVersion: current,
      currentVersionLabel: _packageVersionLabel(packageInfo),
      availableRelease: newestEligible,
    );
  }

  String _packageVersionLabel(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty || build == '0') {
      return info.version;
    }
    return '${info.version}+$build';
  }

  void dispose() {
    _client.close();
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.currentVersionLabel,
    required this.availableRelease,
  });

  final AppSemanticVersion currentVersion;
  final String currentVersionLabel;
  final AppGitHubRelease? availableRelease;

  bool get hasUpdate => availableRelease != null;
}

class AppGitHubRelease {
  const AppGitHubRelease({
    required this.tagName,
    required this.title,
    required this.version,
    required this.releasePageUri,
    required this.apkDownloadUri,
    required this.isPrerelease,
    required this.isDraft,
  });

  final String tagName;
  final String title;
  final AppSemanticVersion version;
  final Uri releasePageUri;
  final Uri? apkDownloadUri;
  final bool isPrerelease;
  final bool isDraft;

  Uri get preferredDownloadUri => apkDownloadUri ?? releasePageUri;

  static AppGitHubRelease? tryFromJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String?)?.trim() ?? '';
    final version = AppSemanticVersion.tryParse(tagName);
    final page = Uri.tryParse((json['html_url'] as String?)?.trim() ?? '');
    if (tagName.isEmpty || version == null || page == null || !page.hasScheme) {
      return null;
    }

    Uri? apkDownloadUri;
    final assets = json['assets'];
    if (assets is List<dynamic>) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }
        final name = (asset['name'] as String?)?.trim() ?? '';
        if (!name.toLowerCase().endsWith('.apk')) {
          continue;
        }
        final candidate = Uri.tryParse(
          (asset['browser_download_url'] as String?)?.trim() ?? '',
        );
        if (candidate != null && candidate.hasScheme) {
          apkDownloadUri = candidate;
          break;
        }
      }
    }

    final rawTitle = (json['name'] as String?)?.trim() ?? '';
    return AppGitHubRelease(
      tagName: tagName,
      title: rawTitle.isEmpty ? tagName : rawTitle,
      version: version,
      releasePageUri: page,
      apkDownloadUri: apkDownloadUri,
      isPrerelease: json['prerelease'] == true,
      isDraft: json['draft'] == true,
    );
  }
}

class AppSemanticVersion implements Comparable<AppSemanticVersion> {
  const AppSemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  bool get isPrerelease => prerelease.isNotEmpty;

  String get normalized {
    final base = '$major.$minor.$patch';
    return isPrerelease ? '$base-${prerelease.join('.')}' : base;
  }

  static AppSemanticVersion? tryParse(String input) {
    final withoutBuild = input.trim().split('+').first;
    final normalizedInput = withoutBuild.replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$',
    ).firstMatch(normalizedInput);
    if (match == null) {
      return null;
    }

    final prereleaseValue = match.group(4);
    return AppSemanticVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: prereleaseValue == null || prereleaseValue.isEmpty
          ? const <String>[]
          : prereleaseValue.split('.'),
    );
  }

  @override
  int compareTo(AppSemanticVersion other) {
    var comparison = major.compareTo(other.major);
    if (comparison != 0) return comparison;
    comparison = minor.compareTo(other.minor);
    if (comparison != 0) return comparison;
    comparison = patch.compareTo(other.patch);
    if (comparison != 0) return comparison;

    if (!isPrerelease && !other.isPrerelease) return 0;
    if (!isPrerelease) return 1;
    if (!other.isPrerelease) return -1;

    final length = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < length; index++) {
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);

      if (leftNumber != null && rightNumber != null) {
        comparison = leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        comparison = -1;
      } else if (rightNumber != null) {
        comparison = 1;
      } else {
        comparison = left.compareTo(right);
      }

      if (comparison != 0) return comparison;
    }

    return prerelease.length.compareTo(other.prerelease.length);
  }

  @override
  String toString() => normalized;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
