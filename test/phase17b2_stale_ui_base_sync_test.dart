import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/repositories/account_repository.dart';

void main() {
  group('resolveOwnedBusinessMutationBaseSyncVersion', () {
    test('uses refreshed owned-cache version instead of stale UI zero', () {
      expect(
        resolveOwnedBusinessMutationBaseSyncVersion(
          cachedSyncVersion: 746,
          requestedSyncVersion: 0,
        ),
        746,
      );
    });

    test('never downgrades a newer requested version', () {
      expect(
        resolveOwnedBusinessMutationBaseSyncVersion(
          cachedSyncVersion: 746,
          requestedSyncVersion: 757,
        ),
        757,
      );
    });

    test('uses cache when requested version is older', () {
      expect(
        resolveOwnedBusinessMutationBaseSyncVersion(
          cachedSyncVersion: 746,
          requestedSyncVersion: 700,
        ),
        746,
      );
    });

    test('uses requested version when cache is unavailable', () {
      expect(
        resolveOwnedBusinessMutationBaseSyncVersion(
          requestedSyncVersion: 635,
        ),
        635,
      );
    });

    test('falls back to zero only when no valid version exists', () {
      expect(resolveOwnedBusinessMutationBaseSyncVersion(), 0);
      expect(
        resolveOwnedBusinessMutationBaseSyncVersion(
          cachedSyncVersion: -1,
          requestedSyncVersion: -5,
        ),
        0,
      );
    });
  });

  test(
      'AccountRepository update path uses resolved version for cache and queue',
      () async {
    final source = await File(
      'lib/data/repositories/account_repository.dart',
    ).readAsString();

    expect(
      source,
      contains(
        'final resolvedBaseSyncVersion = isCreate\n'
        '        ? 0\n'
        '        : resolveOwnedBusinessMutationBaseSyncVersion(',
      ),
    );
    expect(
      source,
      contains('cachedSyncVersion: cachedBusiness?.syncVersion,'),
    );
    expect(
      source,
      contains('requestedSyncVersion: baseSyncVersion,'),
    );
    expect(
      source,
      contains('syncVersion: resolvedBaseSyncVersion,'),
    );
    expect(
      source,
      contains(
        "if (!isCreate) '_base_sync_version': resolvedBaseSyncVersion,",
      ),
    );
    expect(
      source,
      isNot(contains(
          "if (!isCreate) '_base_sync_version': baseSyncVersion ?? 0,")),
    );
  });
}
