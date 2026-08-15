import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/location/business_location.dart';
import '../../core/services/supabase_service.dart';
import '../../models/account_business.dart';
import '../../models/account_profile.dart';
import '../../models/business_contact_draft.dart';
import '../../models/business_contact_number.dart';
import '../directory_data_store.dart';
import '../local/database/local_directory_database.dart';
import '../sync_queue/supabase_sync_queue_gateway.dart';
import '../sync_queue/sync_queue_item.dart';

/// Resolves the optimistic-concurrency base version for an owned-business
/// mutation.
///
/// The edit UI can stay alive across a successful background create/update and
/// therefore hand back an older sync version (commonly 0 immediately after a
/// create). The owned-business cache is refreshed from the successful server
/// snapshot. Never downgrade either known version: use the newest valid value.
int resolveOwnedBusinessMutationBaseSyncVersion({
  int? cachedSyncVersion,
  int? requestedSyncVersion,
}) {
  var resolved = 0;

  for (final candidate in <int?>[
    cachedSyncVersion,
    requestedSyncVersion,
  ]) {
    if (candidate != null && candidate >= 0 && candidate > resolved) {
      resolved = candidate;
    }
  }

  return resolved;
}

class AccountSnapshot {
  const AccountSnapshot({
    required this.profile,
    this.business,
    this.businesses = const <AccountBusiness>[],
    this.isOffline = false,
  });

  final AccountProfile profile;
  final AccountBusiness? business;
  final List<AccountBusiness> businesses;
  final bool isOffline;

  List<AccountBusiness> get allBusinesses {
    if (businesses.isNotEmpty) {
      return businesses;
    }
    final selected = business;
    return selected == null
        ? const <AccountBusiness>[]
        : <AccountBusiness>[selected];
  }
}

class AccountSaveResult {
  const AccountSaveResult({
    required this.snapshot,
    required this.queuedOperationCount,
    required this.message,
    this.imageWarning,
  });

  final AccountSnapshot snapshot;
  final int queuedOperationCount;
  final String message;
  final String? imageWarning;

  bool get wasQueued => queuedOperationCount > 0;
}

class AccountDeleteResult {
  const AccountDeleteResult({
    required this.message,
    required this.operationId,
  });

  final String message;
  final String operationId;
}

class AccountRepository {
  AccountRepository({
    LocalDirectoryDatabase? database,
    DirectoryDataStore? directoryStore,
  })  : _database = database ?? LocalDirectoryDatabase.instance,
        _directoryStore = directoryStore ?? DirectoryDataStore.instance;

  final LocalDirectoryDatabase _database;
  final DirectoryDataStore _directoryStore;

  SupabaseClient get _client => SupabaseService.client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AccountFailure('يجب تسجيل الدخول أولًا.');
    }
    return user;
  }

  Future<AccountSnapshot> loadCurrentAccount({
    String? preferredBusinessId,
  }) async {
    final user = _user;
    final cachedProfile = await _database.readAccountProfile(
      userId: user.id,
    );
    final cachedBusinesses = await _database.readOwnedBusinessesCache(
      userId: user.id,
    );
    final fallbackProfile = cachedProfile ?? _profileFromUser(user);

    try {
      final profile = await _loadOrCreateProfile(user);
      await _database.upsertAccountProfile(profile);
      if (!profile.isActive) {
        throw AccountSuspendedFailure(profile);
      }

      final remoteBusinesses = await _loadOwnedBusinesses(user.id);
      final remoteIds = remoteBusinesses.map((business) => business.id).toSet();
      final localOnly = cachedBusinesses.where((business) {
        return !remoteIds.contains(business.id) &&
            (business.isWaitingForSync || business.hasSyncFailure);
      }).toList(growable: false);
      final merged = <AccountBusiness>[
        ...localOnly,
        ...remoteBusinesses,
      ];

      await _database.deleteOwnedBusinessCache(userId: user.id);
      for (final business in merged) {
        await _database.upsertOwnedBusinessCache(business);
      }

      return AccountSnapshot(
        profile: profile,
        business: _selectBusiness(merged, preferredBusinessId),
        businesses: List<AccountBusiness>.unmodifiable(merged),
      );
    } on AccountSuspendedFailure {
      rethrow;
    } catch (_) {
      await _database.upsertAccountProfile(fallbackProfile);
      return AccountSnapshot(
        profile: fallbackProfile,
        business: _selectBusiness(cachedBusinesses, preferredBusinessId),
        businesses: List<AccountBusiness>.unmodifiable(cachedBusinesses),
        isOffline: true,
      );
    }
  }

  Future<AccountProfile> updateProfileAvatar(String avatarUrl) async {
    final user = _user;
    await _ensureCachedAccountActive(user.id);
    final normalizedUrl = avatarUrl.trim();
    if (normalizedUrl.isEmpty) {
      throw const AccountFailure('رابط الصورة الشخصية غير صالح.');
    }

    try {
      final rows = await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_url': normalizedUrl})
          .eq('id', user.id)
          .select(
            'id, full_name, email, phone, avatar_url, role, is_active, '
            'deleted_at, suspension_reason',
          )
          .limit(1);
      if (rows.isEmpty) {
        throw const AccountFailure('تعذر تحديث الصورة الشخصية.');
      }
      final profile = AccountProfile.fromMap(rows.first);
      await _database.upsertAccountProfile(profile);
      return profile;
    } on AccountFailure {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AccountFailure('لا تملك صلاحية تحديث الصورة الشخصية.');
      }
      throw const AccountFailure(
        'تعذر تحديث الصورة الشخصية. تحقق من الاتصال ثم أعد المحاولة.',
      );
    }
  }

  Future<AccountProfile> updateProfileDetails({
    required String fullName,
    required String phone,
  }) async {
    final user = _user;
    await _ensureCachedAccountActive(user.id);

    final normalizedName = fullName.trim();
    final normalizedPhone = phone.trim();
    if (normalizedName.isEmpty) {
      throw const AccountFailure('أدخل الاسم الشخصي.');
    }

    try {
      final rows = await _client
          .from('profiles')
          .update(<String, dynamic>{
            'full_name': normalizedName,
            'phone': normalizedPhone,
          })
          .eq('id', user.id)
          .select(
            'id, full_name, email, phone, avatar_url, role, is_active, '
            'deleted_at, suspension_reason',
          )
          .limit(1);

      if (rows.isEmpty) {
        throw const AccountFailure('تعذر تحديث بيانات الحساب.');
      }

      final profile = AccountProfile.fromMap(rows.first);
      await _database.upsertAccountProfile(profile);

      try {
        await _client.auth.updateUser(
          UserAttributes(
            data: <String, dynamic>{
              'full_name': profile.fullName,
            },
          ),
        );
      } catch (_) {
        // The profiles row is the source of truth. Metadata refresh is best effort.
      }

      return profile;
    } on AccountFailure {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AccountFailure('لا تملك صلاحية تحديث بيانات الحساب.');
      }
      throw const AccountFailure(
        'تعذر تحديث بيانات الحساب. تحقق من الاتصال ثم أعد المحاولة.',
      );
    } catch (_) {
      throw const AccountFailure(
        'تعذر تحديث بيانات الحساب. تحقق من الاتصال ثم أعد المحاولة.',
      );
    }
  }

  Future<AccountProfile> clearProfileAvatar() async {
    final user = _user;
    await _ensureCachedAccountActive(user.id);

    try {
      final rows = await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_url': null})
          .eq('id', user.id)
          .select(
            'id, full_name, email, phone, avatar_url, role, is_active, '
            'deleted_at, suspension_reason',
          )
          .limit(1);

      if (rows.isEmpty) {
        throw const AccountFailure('تعذر حذف الصورة الشخصية.');
      }

      final profile = AccountProfile.fromMap(rows.first);
      await _database.upsertAccountProfile(profile);
      return profile;
    } on AccountFailure {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AccountFailure('لا تملك صلاحية حذف الصورة الشخصية.');
      }
      throw const AccountFailure(
        'تعذر حذف الصورة الشخصية. تحقق من الاتصال ثم أعد المحاولة.',
      );
    } catch (_) {
      throw const AccountFailure(
        'تعذر حذف الصورة الشخصية. تحقق من الاتصال ثم أعد المحاولة.',
      );
    }
  }

  Future<AccountSaveResult> saveAccount({
    required String categoryId,
    required String categoryName,
    required String businessName,
    required String businessPhone,
    required String whatsapp,
    List<BusinessContactDraft> contactNumbers = const <BusinessContactDraft>[],
    required String description,
    required String address,
    double? latitude,
    double? longitude,
    String? businessId,
    int? baseSyncVersion,
    String? selectedImagePath,
    List<String> selectedGalleryPaths = const <String>[],
  }) async {
    final user = _user;
    await _ensureCachedAccountActive(user.id);
    final normalizedBusinessName = businessName.trim();
    final normalizedAddress =
        address.trim().isEmpty ? 'الحامي' : address.trim();
    late final List<BusinessContactDraft> normalizedContacts;
    try {
      normalizedContacts = BusinessContactDraft.normalizeAndValidate(
        contactNumbers.isNotEmpty
            ? contactNumbers
            : BusinessContactDraft.fromLegacyFields(
                legacyPhone: businessPhone,
                legacyWhatsApp: whatsapp,
                defaultWhatsAppToPrimary: true,
              ),
      );
    } on BusinessContactDraftValidationException catch (error) {
      throw AccountFailure(error.message);
    }
    final normalizedBusinessPhone =
        BusinessContactDraft.primaryPhone(normalizedContacts);
    final normalizedWhatsApp =
        BusinessContactDraft.whatsappPhone(normalizedContacts);

    try {
      BusinessLocation.validatePair(latitude, longitude);
    } on ArgumentError catch (error) {
      throw AccountFailure(error.message?.toString() ?? 'الموقع غير صالح.');
    }

    if (normalizedBusinessName.isEmpty ||
        normalizedBusinessPhone.isEmpty ||
        categoryId.trim().isEmpty) {
      throw const AccountFailure(
        'أكمل الاسم التجاري ورقم الهاتف واختر التصنيف.',
      );
    }

    final cachedProfile = await _database.readAccountProfile(
      userId: user.id,
    );
    final profile = cachedProfile ?? _profileFromUser(user);
    if (cachedProfile == null) {
      await _database.upsertAccountProfile(profile);
    }

    final savedBusinessId = businessId?.trim().isNotEmpty == true
        ? businessId!.trim()
        : _createUuidV4();
    final isCreate = businessId == null || businessId.trim().isEmpty;
    final cachedBusiness = isCreate
        ? null
        : await _database.readOwnedBusinessCacheById(
            userId: user.id,
            businessId: savedBusinessId,
          );
    final resolvedBaseSyncVersion = isCreate
        ? 0
        : resolveOwnedBusinessMutationBaseSyncVersion(
            cachedSyncVersion: cachedBusiness?.syncVersion,
            requestedSyncVersion: baseSyncVersion,
          );
    final localLogoPath = selectedImagePath?.trim().isNotEmpty == true
        ? selectedImagePath!.trim()
        : null;
    final localGalleryPaths = List<String>.unmodifiable(
      selectedGalleryPaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .take(5),
    );

    final localContacts = <BusinessContactNumber>[
      for (var index = 0; index < normalizedContacts.length; index++)
        normalizedContacts[index].toLocalContactNumber(
          businessId: savedBusinessId,
          index: index,
        ),
    ];

    final localBusiness = AccountBusiness(
      id: savedBusinessId,
      ownerId: user.id,
      categoryId: categoryId.trim(),
      categoryName: categoryName.trim(),
      name: normalizedBusinessName,
      description: description.trim(),
      phone: normalizedBusinessPhone,
      whatsapp: normalizedWhatsApp,
      contactNumbers: List<BusinessContactNumber>.unmodifiable(localContacts),
      address: normalizedAddress,
      status: 'local_pending',
      isActive: true,
      localLogoPath: localLogoPath,
      galleryImages: cachedBusiness?.galleryImages ?? const [],
      localGalleryPaths: localGalleryPaths,
      latitude: latitude,
      longitude: longitude,
      syncVersion: resolvedBaseSyncVersion,
    );
    await _database.upsertOwnedBusinessCache(localBusiness);

    final payload = <String, dynamic>{
      'category_id': categoryId.trim(),
      'name': normalizedBusinessName,
      'description': description.trim(),
      'phone': normalizedBusinessPhone,
      'whatsapp': normalizedWhatsApp,
      'contact_numbers': normalizedContacts
          .map((item) => item.toPayloadMap())
          .toList(growable: false),
      'address': normalizedAddress,
      'latitude': latitude,
      'longitude': longitude,
      if (localLogoPath != null)
        SupabaseSyncQueueGateway.localLogoPathKey: localLogoPath,
      if (localGalleryPaths.isNotEmpty)
        SupabaseSyncQueueGateway.localGalleryPathsKey: localGalleryPaths,
      if (!isCreate) '_base_sync_version': resolvedBaseSyncVersion,
      'submit_for_review': true,
    };

    await _directoryStore.enqueueBusinessOperation(
      operationType: isCreate
          ? SyncQueueOperationType.create
          : SyncQueueOperationType.update,
      entityId: savedBusinessId,
      payload: payload,
      priority: 10,
    );

    const queuedOperationCount = 1;

    final cachedBusinesses = await _database.readOwnedBusinessesCache(
      userId: user.id,
    );
    final orderedBusinesses = <AccountBusiness>[
      localBusiness,
      ...cachedBusinesses.where(
        (business) => business.id != localBusiness.id,
      ),
    ];

    return AccountSaveResult(
      snapshot: AccountSnapshot(
        profile: profile,
        business: localBusiness,
        businesses: List<AccountBusiness>.unmodifiable(orderedBusinesses),
        isOffline: !_directoryStore.usesSupabase,
      ),
      queuedOperationCount: queuedOperationCount,
      message: _directoryStore.usesSupabase
          ? 'تم حفظ النشاط وسيُرسل للمراجعة تلقائيًا.'
          : 'تم حفظ النشاط في الجهاز وسيُرسل عند عودة الإنترنت.',
      imageWarning: localLogoPath == null && localGalleryPaths.isEmpty
          ? null
          : 'ستُرفع صور النشاط تلقائيًا مع عملية المزامنة.',
    );
  }

  Future<AccountDeleteResult> deleteOwnedBusiness(
    String businessId,
  ) async {
    final user = _user;
    await _ensureCachedAccountActive(user.id);
    final cachedBusiness = await _database.readOwnedBusinessCacheById(
      userId: user.id,
      businessId: businessId,
    );
    final item = await _directoryStore.enqueueBusinessOperation(
      operationType: SyncQueueOperationType.deleteEntity,
      entityId: businessId,
      payload: <String, dynamic>{
        '_base_sync_version': cachedBusiness?.syncVersion ?? 0,
      },
      priority: 20,
    );
    await _database.deleteOwnedBusinessCache(
      userId: user.id,
      businessId: businessId,
    );

    return AccountDeleteResult(
      operationId: item.id,
      message: _directoryStore.usesSupabase
          ? 'تم إرسال طلب حذف النشاط.'
          : 'تم حفظ طلب الحذف وسيُرسل عند عودة الإنترنت.',
    );
  }

  Future<void> _ensureCachedAccountActive(String userId) async {
    final profile = await _database.readAccountProfile(userId: userId);
    if (profile != null && !profile.isActive) {
      throw AccountSuspendedFailure(profile);
    }
  }

  Future<AccountProfile> _loadOrCreateProfile(User user) async {
    final rows = await _client
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, is_active, '
          'deleted_at, suspension_reason',
        )
        .eq('id', user.id)
        .limit(1);

    if (rows.isNotEmpty) {
      return AccountProfile.fromMap(rows.first);
    }

    final inserted = await _client
        .from('profiles')
        .upsert(
          <String, dynamic>{
            'id': user.id,
            'full_name': user.userMetadata?['full_name']?.toString() ??
                user.userMetadata?['name']?.toString() ??
                '',
            'email': user.email,
            'phone': user.phone,
            'avatar_url': user.userMetadata?['avatar_url']?.toString() ??
                user.userMetadata?['picture']?.toString(),
          },
          onConflict: 'id',
        )
        .select(
          'id, full_name, email, phone, avatar_url, role, is_active, '
          'deleted_at, suspension_reason',
        )
        .single();

    return AccountProfile.fromMap(inserted);
  }

  Future<List<AccountBusiness>> _loadOwnedBusinesses(String userId) async {
    final rows = await _client
        .from('businesses')
        .select(
          'id, owner_id, category_id, name, description, phone, '
          'whatsapp, address, latitude, longitude, logo_url, status, rejection_reason, '
          'is_active, sync_version, created_at, updated_at, '
          'categories!businesses_category_id_fkey(id, name_ar, slug), '
          'business_images(id, business_id, storage_path, public_url, '
          'alt_text, sort_order, is_primary, created_at, updated_at, '
          'deleted_at, sync_version), '
          'business_contact_numbers(id, business_id, phone_number, label, '
          'is_primary, supports_whatsapp, sort_order, created_at, updated_at, '
          'deleted_at, sync_version)',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return rows.map(AccountBusiness.fromMap).toList(growable: false);
  }

  AccountBusiness? _selectBusiness(
    List<AccountBusiness> businesses,
    String? preferredBusinessId,
  ) {
    final preferred = preferredBusinessId?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      for (final business in businesses) {
        if (business.id == preferred) {
          return business;
        }
      }
    }
    return businesses.isEmpty ? null : businesses.first;
  }

  AccountProfile _profileFromUser(User user) {
    return AccountProfile(
      id: user.id,
      fullName: user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          '',
      phone: user.phone ?? '',
      role: 'user',
      isActive: true,
      email: user.email,
      avatarUrl: user.userMetadata?['avatar_url']?.toString() ??
          user.userMetadata?['picture']?.toString(),
    );
  }

  String _createUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountSuspendedFailure extends AccountFailure {
  AccountSuspendedFailure(this.profile)
      : super(
          profile.isDeleted
              ? 'تم حذف هذا الحساب ظاهريًا من الإدارة. لا يمكن إدارة الأنشطة '
                  'أو مزامنتها حتى استعادة الحساب.'
              : 'تم إيقاف هذا الحساب من الإدارة. لا يمكن إدارة الأنشطة أو '
                  'مزامنتها حتى إعادة تفعيل الحساب.',
        );

  final AccountProfile profile;
}
