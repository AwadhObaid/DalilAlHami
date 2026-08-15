import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/data/local/database/local_directory_database.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_item.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_processor.dart';
import 'package:hami_guide/data/sync_queue/sync_queue_remote_gateway.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'successful create rebases the already queued update before execution',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('dalil_b2_sync_rebase_');
      final path = '${directory.path}${Platform.pathSeparator}directory.db';
      final database = LocalDirectoryDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );

      try {
        final createdAt = DateTime.utc(2026, 8, 15, 0, 0);
        const userId = 'user-1';
        const businessId = 'business-1';

        await database.enqueueSyncOperation(
          SyncQueueEnqueueRequest(
            operationId: 'op-create',
            deduplicationKey: 'op-create',
            userId: userId,
            entityType: SyncQueueEntityType.business,
            operationType: SyncQueueOperationType.create,
            entityId: businessId,
            payload: <String, dynamic>{
              'name': 'QA17B2',
              'phone': '700990001',
              'whatsapp': '700990002',
              'contact_numbers': <Map<String, dynamic>>[
                <String, dynamic>{
                  'phone_number': '700990001',
                  'label': 'الرئيسي',
                  'is_primary': true,
                  'supports_whatsapp': false,
                  'sort_order': 0,
                },
                <String, dynamic>{
                  'phone_number': '700990002',
                  'label': 'المبيعات',
                  'is_primary': false,
                  'supports_whatsapp': true,
                  'sort_order': 1,
                },
              ],
              'submit_for_review': true,
            },
            createdAt: createdAt,
          ),
        );

        await database.enqueueSyncOperation(
          SyncQueueEnqueueRequest(
            operationId: 'op-update',
            deduplicationKey: 'op-update',
            userId: userId,
            entityType: SyncQueueEntityType.business,
            operationType: SyncQueueOperationType.update,
            entityId: businessId,
            payload: <String, dynamic>{
              '_base_sync_version': 0,
              'name': 'QA17B2',
              'phone': '700990003',
              'whatsapp': '700990003',
              'contact_numbers': <Map<String, dynamic>>[
                <String, dynamic>{
                  'phone_number': '700990003',
                  'label': 'الإدارة',
                  'is_primary': true,
                  'supports_whatsapp': true,
                  'sort_order': 0,
                },
                <String, dynamic>{
                  'phone_number': '700990001',
                  'label': 'الرئيسي',
                  'is_primary': false,
                  'supports_whatsapp': false,
                  'sort_order': 1,
                },
                <String, dynamic>{
                  'phone_number': '700990002',
                  'label': 'المبيعات',
                  'is_primary': false,
                  'supports_whatsapp': false,
                  'sort_order': 2,
                },
              ],
              'submit_for_review': true,
            },
            createdAt: createdAt.add(const Duration(seconds: 1)),
          ),
        );

        final gateway = _CreateThenUpdateGateway(
          userId: userId,
          businessId: businessId,
        );
        final processor = SyncQueueProcessor(
          database: database,
          gateway: gateway,
          userId: userId,
          clock: () => createdAt.add(const Duration(minutes: 1)),
        );

        final report = await processor.processPending();

        expect(report.completed, 2);
        expect(report.failed, 0);
        expect(report.conflicts, 0);
        expect(gateway.seenOperations, <String>['create', 'update']);
        expect(gateway.updateBaseSyncVersion, 635);

        final operations = await database.readSyncOperations(userId: userId);
        final update = operations.singleWhere((item) => item.id == 'op-update');

        expect(update.status, SyncQueueStatus.completed);
        expect(update.payload['_base_sync_version'], 635);

        final contacts = update.payload['contact_numbers'] as List<dynamic>;
        expect(contacts, hasLength(3));
        expect(
          (contacts.first as Map<dynamic, dynamic>)['phone_number'],
          '700990003',
        );
        expect(
          (contacts.first as Map<dynamic, dynamic>)['is_primary'],
          isTrue,
        );
        expect(
          (contacts.first as Map<dynamic, dynamic>)['supports_whatsapp'],
          isTrue,
        );

        final cached = await database.readOwnedBusinessCacheById(
          userId: userId,
          businessId: businessId,
        );
        expect(cached, isNotNull);
        expect(cached!.syncVersion, 640);
        expect(cached.contactNumbers, hasLength(3));
        expect(cached.contactNumbers.first.phoneNumber, '700990003');
        expect(cached.contactNumbers.first.isPrimary, isTrue);
        expect(cached.contactNumbers.first.supportsWhatsApp, isTrue);
      } finally {
        await database.close();
        if (await databaseFactoryFfi.databaseExists(path)) {
          await databaseFactoryFfi.deleteDatabase(path);
        }
        await directory.delete(recursive: true);
      }
    },
  );

  test('rebase also updates an actionable queued delete', () async {
    final directory =
        await Directory.systemTemp.createTemp('dalil_b2_delete_rebase_');
    final path = '${directory.path}${Platform.pathSeparator}directory.db';
    final database = LocalDirectoryDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: path,
    );

    try {
      const userId = 'user-2';
      const businessId = 'business-2';

      await database.enqueueSyncOperation(
        SyncQueueEnqueueRequest(
          operationId: 'op-delete',
          deduplicationKey: 'op-delete',
          userId: userId,
          entityType: SyncQueueEntityType.business,
          operationType: SyncQueueOperationType.deleteEntity,
          entityId: businessId,
          payload: const <String, dynamic>{
            '_base_sync_version': 0,
          },
          createdAt: DateTime.utc(2026, 8, 15),
        ),
      );

      final changed = await database.rebasePendingBusinessSyncOperations(
        userId: userId,
        entityId: businessId,
        baseSyncVersion: 91,
      );

      expect(changed, 1);
      final operations = await database.readSyncOperations(userId: userId);
      final deletion = operations.singleWhere((item) => item.id == 'op-delete');
      expect(deletion.payload['_base_sync_version'], 91);
      expect(deletion.operationType, SyncQueueOperationType.deleteEntity);
    } finally {
      await database.close();
      if (await databaseFactoryFfi.databaseExists(path)) {
        await databaseFactoryFfi.deleteDatabase(path);
      }
      await directory.delete(recursive: true);
    }
  });
}

class _CreateThenUpdateGateway implements SyncQueueRemoteGateway {
  _CreateThenUpdateGateway({
    required this.userId,
    required this.businessId,
  });

  final String userId;
  final String businessId;

  final List<String> seenOperations = <String>[];
  int? updateBaseSyncVersion;

  @override
  Future<SyncQueueRemoteResult> execute(SyncQueueItem item) async {
    seenOperations.add(item.operationType.databaseValue);

    switch (item.operationType) {
      case SyncQueueOperationType.create:
        return SyncQueueRemoteResult(
          operationId: item.id,
          operationType: item.operationType.databaseValue,
          entityId: businessId,
          remoteStatus: 'pending',
          serverSyncVersion: 635,
          serverSnapshot: _snapshot(
            syncVersion: 635,
            contacts: const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'contact-1',
                'business_id': 'business-1',
                'phone_number': '700990001',
                'label': 'الرئيسي',
                'is_primary': true,
                'supports_whatsapp': false,
                'sort_order': 0,
                'sync_version': 631,
              },
              <String, dynamic>{
                'id': 'contact-2',
                'business_id': 'business-1',
                'phone_number': '700990002',
                'label': 'المبيعات',
                'is_primary': false,
                'supports_whatsapp': true,
                'sort_order': 1,
                'sync_version': 633,
              },
            ],
          ),
          raw: const <String, dynamic>{
            'remote_status': 'pending',
            'server_sync_version': 635,
          },
        );

      case SyncQueueOperationType.update:
        updateBaseSyncVersion =
            (item.payload['_base_sync_version'] as num?)?.toInt();
        if (updateBaseSyncVersion != 635) {
          throw StateError(
            'Queued update was not rebased before remote execution: '
            '$updateBaseSyncVersion',
          );
        }

        return SyncQueueRemoteResult(
          operationId: item.id,
          operationType: item.operationType.databaseValue,
          entityId: businessId,
          remoteStatus: 'pending',
          serverSyncVersion: 640,
          serverSnapshot: _snapshot(
            syncVersion: 640,
            phone: '700990003',
            whatsapp: '700990003',
            contacts: const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'contact-3',
                'business_id': 'business-1',
                'phone_number': '700990003',
                'label': 'الإدارة',
                'is_primary': true,
                'supports_whatsapp': true,
                'sort_order': 0,
                'sync_version': 636,
              },
              <String, dynamic>{
                'id': 'contact-1',
                'business_id': 'business-1',
                'phone_number': '700990001',
                'label': 'الرئيسي',
                'is_primary': false,
                'supports_whatsapp': false,
                'sort_order': 1,
                'sync_version': 638,
              },
              <String, dynamic>{
                'id': 'contact-2',
                'business_id': 'business-1',
                'phone_number': '700990002',
                'label': 'المبيعات',
                'is_primary': false,
                'supports_whatsapp': false,
                'sort_order': 2,
                'sync_version': 639,
              },
            ],
          ),
          raw: const <String, dynamic>{
            'remote_status': 'pending',
            'server_sync_version': 640,
          },
        );

      case SyncQueueOperationType.deleteEntity:
      case SyncQueueOperationType.submitForReview:
        throw StateError(
          'Unexpected operation in create/update rebase regression: '
          '${item.operationType.databaseValue}',
        );
    }
  }

  Map<String, dynamic> _snapshot({
    required int syncVersion,
    required List<Map<String, dynamic>> contacts,
    String phone = '700990001',
    String whatsapp = '700990002',
  }) {
    return <String, dynamic>{
      'id': businessId,
      'owner_id': userId,
      'category_id': 'category-1',
      'category_name': 'خدمات',
      'name': 'QA17B2',
      'description': '',
      'phone': phone,
      'whatsapp': whatsapp,
      'address': 'الحامي',
      'status': 'pending',
      'is_active': true,
      'sync_version': syncVersion,
      'business_contact_numbers': contacts,
    };
  }
}
