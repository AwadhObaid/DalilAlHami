import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/location/business_location.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/media_upload_service.dart';
import '../../data/directory_data_store.dart';
import '../../data/repositories/account_repository.dart';
import '../../models/account_business.dart';
import '../../models/account_profile.dart';
import '../shared/widgets/business_gallery_manager.dart';
import '../shared/widgets/business_location_picker.dart';
import '../shared/widgets/cached_directory_image.dart';
import 'widgets/add_business_button.dart';
import 'widgets/business_category_dropdown.dart';
import 'widgets/empty_owned_business_state.dart';
import 'widgets/local_business_gallery_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    this.startInCreateMode = false,
    this.businessId,
    super.key,
  });

  final bool startInCreateMode;
  final String? businessId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AccountRepository _repository = AccountRepository();
  final DirectoryDataStore _directoryStore = DirectoryDataStore.instance;
  final ImagePicker _picker = ImagePicker();
  final MediaUploadService _mediaUploadService = MediaUploadService();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _addressController =
      TextEditingController(text: 'الحامي');
  final TextEditingController _descriptionController = TextEditingController();

  AccountProfile? _profile;
  AccountBusiness? _business;
  AccountBusiness? _businessBeforeCreate;
  String? _selectedCategoryId;
  String? _selectedImagePath;
  List<String> _selectedGalleryPaths = const <String>[];
  BusinessLocation? _selectedBusinessLocation;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isEditing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _directoryStore.addListener(_handleDirectoryChanged);
    _loadAccount();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _directoryStore.removeListener(_handleDirectoryChanged);
    super.dispose();
  }

  void _handleDirectoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAccount() async {
    if (!AuthSessionStore.instance.isAuthenticated) {
      setState(() {
        _isLoading = false;
        _loadError = 'انتهت جلسة تسجيل الدخول.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      if (!_directoryStore.hasLoaded) {
        await _directoryStore.load();
      }

      final snapshot = await _repository.loadCurrentAccount(
        preferredBusinessId: widget.businessId,
      );

      if (!mounted) {
        return;
      }

      _applySnapshot(snapshot);

      if (widget.startInCreateMode) {
        _prepareCreateForm();
      }

      setState(() {
        _isLoading = false;
        _isEditing = widget.startInCreateMode;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = _messageForError(error);
      });
    }
  }

  void _applySnapshot(AccountSnapshot snapshot) {
    _profile = snapshot.profile;
    _business = snapshot.business;

    _fullNameController.text = snapshot.profile.fullName.isNotEmpty
        ? snapshot.profile.fullName
        : snapshot.business?.name ?? '';
    _businessNameController.text = snapshot.business?.name ?? '';
    _phoneController.text = snapshot.business?.phone ?? snapshot.profile.phone;
    _whatsappController.text = snapshot.business?.whatsapp ?? '';
    _addressController.text = snapshot.business?.address ?? 'الحامي';
    _descriptionController.text = snapshot.business?.description ?? '';
    _selectedImagePath = null;
    _selectedGalleryPaths =
        snapshot.business?.localGalleryPaths ?? const <String>[];
    _selectedBusinessLocation = snapshot.business?.location;

    _selectedCategoryId = snapshot.business?.categoryId;
  }

  Future<void> _uploadProfileAvatar() async {
    final profile = _profile;
    if (profile == null || _isUploadingAvatar || _isSaving) {
      return;
    }

    setState(() => _isUploadingAvatar = true);
    MediaUploadResult? upload;
    try {
      upload = await _mediaUploadService.pickAndUpload(
        kind: MediaAssetKind.profileAvatar,
        entityId: profile.id,
      );
      if (upload == null || !mounted) {
        return;
      }

      final updated = await _repository.updateProfileAvatar(upload.publicUrl);
      if (!mounted) {
        return;
      }

      setState(() => _profile = updated);
      await _deleteAvatarBestEffort(
        profile.avatarUrl,
        exceptValue: upload.publicUrl,
      );
      _showMessage('تم تحديث الصورة الشخصية.');
    } catch (error) {
      final uploadedValue = upload?.publicUrl;
      if (uploadedValue != null) {
        await _deleteAvatarBestEffort(uploadedValue);
      }
      if (mounted) {
        _showMessage(_messageForError(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _deleteAvatarBestEffort(
    String? value, {
    String? exceptValue,
  }) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized == exceptValue?.trim()) {
      return;
    }
    try {
      await _mediaUploadService.deleteAsset(
        kind: MediaAssetKind.profileAvatar,
        value: normalized,
      );
    } catch (_) {
      // Cleanup is intentionally best effort. The admin media cleanup tool can
      // remove any unreferenced object later without blocking profile updates.
    }
  }

  Future<void> _pickImage() async {
    final selectedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (!mounted || selectedImage == null) {
      return;
    }

    setState(() {
      _selectedImagePath = selectedImage.path;
    });
  }

  Future<void> _saveAccount() async {
    if (_isSaving) {
      return;
    }

    final selectedCategory = BusinessCategoryDropdown.categoryForId(
      _directoryStore.categories,
      _selectedCategoryId,
    );

    if (_fullNameController.text.trim().isEmpty ||
        _businessNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        selectedCategory == null) {
      _showMessage(
        'أكمل الاسم التجاري ورقم الهاتف واختر التصنيف.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _repository.saveAccount(
        fullName: _fullNameController.text,
        categoryId: selectedCategory.id.trim(),
        categoryName: selectedCategory.name,
        businessName: _businessNameController.text,
        businessPhone: _phoneController.text,
        whatsapp: _whatsappController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        latitude: _selectedBusinessLocation?.latitude,
        longitude: _selectedBusinessLocation?.longitude,
        businessId: _business?.id,
        baseSyncVersion: _business?.syncVersion,
        selectedImagePath: _selectedImagePath,
        selectedGalleryPaths: _selectedGalleryPaths,
      );

      if (!mounted) {
        return;
      }

      _applySnapshot(result.snapshot);
      _businessBeforeCreate = null;

      setState(() {
        _isEditing = false;
      });

      _showMessage(result.message);
      if (result.imageWarning != null) {
        _showMessage(result.imageWarning!);
      }
    } catch (error) {
      _showMessage(
        _messageForError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text(
            'هل تريد تسجيل الخروج من هذا الجهاز؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await AuthSessionStore.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      _showMessage(
        _messageForError(error),
        isError: true,
      );
    }
  }

  Future<void> _deleteBusiness() async {
    final business = _business;
    if (business == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف النشاط'),
          content: const Text(
            'سيتم حذف بيانات النشاط من الدليل، '
            'لكن حساب تسجيل الدخول سيبقى موجودًا.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('حذف النشاط'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _repository.deleteOwnedBusiness(business.id);

      if (!mounted) {
        return;
      }

      _showMessage(result.message);
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        _messageForError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _messageForError(Object error) {
    if (error is AccountFailure) {
      return error.message;
    }

    final text = error.toString();

    if (text.contains('row-level security')) {
      return AppLocaleText.runtime(
          'لم تسمح صلاحيات قاعدة البيانات بتنفيذ العملية.');
    }

    if (text.contains('network') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return AppLocaleText.runtime('تعذر الاتصال بالإنترنت.');
    }

    return text.replaceFirst('Exception: ', '');
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _pageTitle {
    if (_business == null) {
      return _isEditing ? 'إضافة نشاط جديد' : 'إدارة نشاطي';
    }

    return _isEditing ? 'تعديل النشاط' : 'إدارة نشاطي';
  }

  void _prepareCreateForm() {
    _businessBeforeCreate ??= _business;
    _business = null;
    _businessNameController.clear();
    _phoneController.text = _profile?.phone ?? '';
    _whatsappController.clear();
    _addressController.text = 'الحامي';
    _descriptionController.clear();
    _selectedCategoryId = null;
    _selectedImagePath = null;
    _selectedGalleryPaths = const <String>[];
    _selectedBusinessLocation = null;
  }

  void _startCreatingBusiness() {
    setState(() {
      _prepareCreateForm();
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    final profile = _profile;
    final previousBusiness = _businessBeforeCreate;

    if (_business == null && previousBusiness != null && profile != null) {
      _applySnapshot(
        AccountSnapshot(
          profile: profile,
          business: previousBusiness,
        ),
      );
      _businessBeforeCreate = null;
    } else {
      final business = _business;
      if (business != null && profile != null) {
        _applySnapshot(
          AccountSnapshot(
            profile: profile,
            business: business,
          ),
        );
      }
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(
          _pageTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
        actions: [
          IconButton(
            tooltip: AppLocaleText.runtime('تسجيل الخروج'),
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAccount,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (_directoryStore.pendingSyncOperationCount > 0 ||
              _directoryStore.failedSyncOperationCount > 0)
            _buildQueueStatusBanner(),
          _isEditing ? _buildEditForm() : _buildProfileView(),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _buildHeaderImage(isEditable: true),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildSectionTitle('بيانات الحساب'),
              _buildProfileAvatarEditor(),
              const SizedBox(height: 12),
              _buildInputCard([
                _buildCustomField(
                  'الاسم الشخصي',
                  _fullNameController,
                  Icons.person_outline,
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionTitle('تفاصيل النشاط'),
              _buildInputCard([
                _buildCustomField(
                  'اسم النشاط',
                  _businessNameController,
                  Icons.storefront_outlined,
                ),
                _buildCustomField(
                  'رقم هاتف النشاط',
                  _phoneController,
                  Icons.phone_outlined,
                  isPhone: true,
                ),
                _buildCategoryDropdown(),
                _buildCustomField(
                  'رقم الواتساب',
                  _whatsappController,
                  Icons.chat_outlined,
                  isPhone: true,
                ),
                _buildCustomField(
                  'العنوان',
                  _addressController,
                  Icons.location_on_outlined,
                ),
                _buildCustomField(
                  'وصف الخدمة',
                  _descriptionController,
                  Icons.description_outlined,
                  lines: 3,
                ),
              ]),
              const SizedBox(height: 12),
              BusinessLocationPicker(
                location: _selectedBusinessLocation,
                enabled: !_isSaving,
                onChanged: (location) {
                  setState(() => _selectedBusinessLocation = location);
                },
              ),
              const SizedBox(height: 20),
              if (_business != null &&
                  !_business!.isWaitingForSync &&
                  !_business!.hasSyncFailure)
                BusinessGalleryManager(
                  businessId: _business!.id,
                  initialImages: _business!.galleryImages,
                  enabled: !_isSaving,
                )
              else
                LocalBusinessGalleryPicker(
                  paths: _selectedGalleryPaths,
                  enabled: !_isSaving,
                  onChanged: (paths) {
                    setState(() => _selectedGalleryPaths = paths);
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveAccount,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _business == null
                        ? 'إرسال النشاط للمراجعة'
                        : 'حفظ وإعادة الإرسال للمراجعة',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isSaving ? null : _cancelEditing,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  _business == null
                      ? 'العودة إلى إدارة نشاطي'
                      : 'إلغاء التعديل',
                ),
              ),
              const SizedBox(height: 35),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    final business = _business;

    if (business == null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildProfileAvatarEditor(),
          ),
          const SizedBox(height: 12),
          EmptyOwnedBusinessState(
            onAddPressed: _startCreatingBusiness,
          ),
        ],
      );
    }

    final moderationColor =
        business.status == 'changes_requested' ? Colors.orange : Colors.red;

    return Column(
      children: [
        _buildHeaderImage(isEditable: false),
        const SizedBox(height: 45),
        Text(
          business.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          business.categoryName,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        _buildStatusChip(business),
        if (business.rejectionReason != null) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: moderationColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: moderationColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              business.status == 'changes_requested'
                  ? 'التعديلات المطلوبة: ${business.rejectionReason}'
                  : 'سبب الرفض: ${business.rejectionReason}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: moderationColor,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.person,
                  'صاحب الحساب',
                  _profile?.fullName ?? '',
                ),
                const Divider(),
                _buildInfoRow(
                  Icons.phone,
                  'رقم الهاتف',
                  business.phone,
                ),
                const Divider(),
                _buildInfoRow(
                  Icons.location_on,
                  'العنوان',
                  business.address,
                ),
                if (business.hasLocation) ...[
                  const Divider(),
                  _buildInfoRow(
                    Icons.map_outlined,
                    'إحداثيات الموقع',
                    business.location!.coordinatesLabel,
                  ),
                ],
                const Divider(),
                _buildInfoRow(
                  Icons.description,
                  'الوصف',
                  business.description.isEmpty
                      ? 'لا يوجد وصف'
                      : business.description,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AddBusinessButton(
            buttonKey: const ValueKey<String>(
              'manage-add-business-button',
            ),
            onPressed: _isSaving ? null : _startCreatingBusiness,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل النشاط'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _deleteBusiness,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف النشاط'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildQueueStatusBanner() {
    final failed = _directoryStore.failedSyncOperationCount;
    final pending = _directoryStore.pendingSyncOperationCount;
    final hasFailure = failed > 0;
    final color = hasFailure ? Colors.red : Colors.orange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            hasFailure
                ? Icons.sync_problem_rounded
                : Icons.cloud_upload_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasFailure
                  ? 'توجد $failed عملية تعذر إرسالها. أعد المحاولة من صفحة حسابي.'
                  : 'توجد $pending عملية محفوظة وستُرسل تلقائيًا عند توفر الإنترنت.',
              style: TextStyle(color: color.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AccountBusiness business) {
    final color = switch (business.status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'changes_requested' => Colors.orange,
      'suspended' => Colors.deepOrange,
      'pending' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        business.statusLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileAvatarEditor() {
    final profile = _profile;
    return Container(
      key: const ValueKey<String>('profile-avatar-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          ClipOval(
            child: CachedDirectoryImage(
              source: profile?.avatarUrl,
              bucket: 'avatars',
              width: 72,
              height: 72,
              placeholder: ColoredBox(
                color: AppColors.primarySoft,
                child: Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryTeal,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الصورة الشخصية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'تظهر داخل حسابك، وهي مستقلة عن شعار النشاط.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey<String>('profile-avatar-upload-action'),
            tooltip: AppLocaleText.runtime('اختيار صورة شخصية'),
            onPressed:
                _isUploadingAvatar || _isSaving ? null : _uploadProfileAvatar,
            icon: _isUploadingAvatar
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage({
    required bool isEditable,
  }) {
    ImageProvider<Object>? imageProvider;

    final selectedImagePath = _selectedImagePath;
    if (selectedImagePath != null &&
        selectedImagePath.isNotEmpty &&
        File(selectedImagePath).existsSync()) {
      imageProvider = FileImage(File(selectedImagePath));
    } else if (_business?.localLogoPath != null &&
        File(_business!.localLogoPath!).existsSync()) {
      imageProvider = FileImage(File(_business!.localLogoPath!));
    } else if (_business?.logoUrl != null) {
      imageProvider = NetworkImage(_business!.logoUrl!);
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 105,
          decoration: const BoxDecoration(
            color: AppColors.primaryTeal,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
        ),
        Positioned(
          top: 42,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 57,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(
                          Icons.storefront,
                          size: 58,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              if (isEditable)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _isSaving ? null : _pickImage,
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.lightTeal,
                      child: Icon(
                        Icons.camera_alt,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return BusinessCategoryDropdown(
      categories: _directoryStore.categories,
      selectedCategoryId: _selectedCategoryId,
      enabled: !_isSaving,
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
    );
  }

  Widget _buildCustomField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int lines = 1,
    bool isPhone = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: controller,
        enabled: enabled && !_isSaving,
        maxLines: lines,
        keyboardType: isPhone
            ? TextInputType.phone
            : lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.primaryTeal,
          ),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryTeal,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value.isEmpty ? 'غير محدد' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 10,
          bottom: 8,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 9,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
