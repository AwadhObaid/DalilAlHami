import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/account_business.dart';
import '../../models/account_profile.dart';

class AccountSnapshot {
  const AccountSnapshot({
    required this.profile,
    required this.business,
  });

  final AccountProfile profile;
  final AccountBusiness? business;
}

class AccountSaveResult {
  const AccountSaveResult({
    required this.snapshot,
    this.imageWarning,
  });

  final AccountSnapshot snapshot;
  final String? imageWarning;
}

class AccountRepository {
  const AccountRepository();

  SupabaseClient get _client => SupabaseService.client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AccountFailure(
        'يجب تسجيل الدخول أولًا.',
      );
    }
    return user;
  }

  Future<AccountSnapshot> loadCurrentAccount() async {
    final user = _user;
    final profile = await _loadOrCreateProfile(user);
    final business = await _loadOwnedBusiness(user.id);

    return AccountSnapshot(
      profile: profile,
      business: business,
    );
  }

  Future<AccountSaveResult> saveAccount({
    required String fullName,
    required String categoryId,
    required String businessName,
    required String businessPhone,
    required String whatsapp,
    required String description,
    required String address,
    String? businessId,
    String? selectedImagePath,
  }) async {
    final user = _user;
    final normalizedName = fullName.trim();
    final normalizedBusinessName = businessName.trim();
    final normalizedAddress =
        address.trim().isEmpty ? 'الحامي' : address.trim();
    final normalizedBusinessPhone = businessPhone.trim();
    final normalizedWhatsApp =
        whatsapp.trim().isEmpty ? normalizedBusinessPhone : whatsapp.trim();

    if (normalizedName.isEmpty ||
        normalizedBusinessName.isEmpty ||
        normalizedBusinessPhone.isEmpty ||
        categoryId.trim().isEmpty) {
      throw const AccountFailure(
        'أكمل الاسم التجاري ورقم الهاتف واختر التصنيف.',
      );
    }

    final profileData = <String, dynamic>{
      'id': user.id,
      'full_name': normalizedName,
      'phone': user.phone,
      'email': user.email,
    };

    await _client.from('profiles').upsert(
          profileData,
          onConflict: 'id',
        );

    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{
            'full_name': normalizedName,
          },
        ),
      );
    } catch (_) {
      // فشل تحديث metadata لا يمنع حفظ ملف التطبيق.
    }

    final businessData = <String, dynamic>{
      'owner_id': user.id,
      'category_id': categoryId,
      'name': normalizedBusinessName,
      'description': description.trim(),
      'phone': normalizedBusinessPhone,
      'whatsapp': normalizedWhatsApp,
      'address': normalizedAddress,
      'status': 'pending',
    };

    String savedBusinessId;

    if (businessId == null || businessId.isEmpty) {
      final inserted = await _client
          .from('businesses')
          .insert(businessData)
          .select('id')
          .single();

      savedBusinessId = inserted['id'].toString();
    } else {
      await _client
          .from('businesses')
          .update(businessData)
          .eq('id', businessId)
          .eq('owner_id', user.id);

      savedBusinessId = businessId;
    }

    String? imageWarning;

    if (selectedImagePath != null && selectedImagePath.trim().isNotEmpty) {
      try {
        final logoUrl = await _uploadBusinessLogo(
          businessId: savedBusinessId,
          localPath: selectedImagePath,
        );

        await _client
            .from('businesses')
            .update(<String, dynamic>{
              'logo_url': logoUrl,
            })
            .eq('id', savedBusinessId)
            .eq('owner_id', user.id);
      } catch (_) {
        imageWarning =
            'تم حفظ النشاط، لكن تعذر رفع الصورة. يمكنك إعادة اختيارها لاحقًا.';
      }
    }

    final snapshot = await loadCurrentAccount();

    return AccountSaveResult(
      snapshot: snapshot,
      imageWarning: imageWarning,
    );
  }

  Future<void> deleteOwnedBusiness(String businessId) async {
    final user = _user;

    await _client
        .from('businesses')
        .delete()
        .eq('id', businessId)
        .eq('owner_id', user.id);
  }

  Future<AccountProfile> _loadOrCreateProfile(User user) async {
    final rows = await _client
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, is_active',
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
          'id, full_name, email, phone, avatar_url, role, is_active',
        )
        .single();

    return AccountProfile.fromMap(inserted);
  }

  Future<AccountBusiness?> _loadOwnedBusiness(
    String userId,
  ) async {
    final rows = await _client
        .from('businesses')
        .select(
          'id, owner_id, category_id, name, description, phone, '
          'whatsapp, address, logo_url, status, rejection_reason, '
          'is_active, categories!businesses_category_id_fkey('
          'id, name_ar, slug'
          ')',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return AccountBusiness.fromMap(rows.first);
  }

  Future<String> _uploadBusinessLogo({
    required String businessId,
    required String localPath,
  }) async {
    final file = File(localPath);

    if (!await file.exists()) {
      throw const AccountFailure(
        'ملف الصورة المختارة غير موجود.',
      );
    }

    final extension = _safeImageExtension(localPath);
    final storagePath =
        '$businessId/logo_${DateTime.now().millisecondsSinceEpoch}'
        '.$extension';

    await _client.storage.from('business-media').upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _contentTypeFor(extension),
          ),
        );

    return _client.storage.from('business-media').getPublicUrl(storagePath);
  }

  String _safeImageExtension(String path) {
    final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(path);
    final extension = match?.group(1)?.toLowerCase();

    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
