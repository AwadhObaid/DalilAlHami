import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/account_repository.dart';
import '../../models/account_profile.dart';
import '../shared/widgets/cached_directory_image.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({super.key});

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  final AccountRepository _repository = AccountRepository();
  final AuthSessionStore _authStore = AuthSessionStore.instance;
  final MediaUploadService _mediaUploadService = MediaUploadService();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  AccountProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDeletingAvatar = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_authStore.isAuthenticated) {
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
      final snapshot = await _repository.loadCurrentAccount();
      if (!mounted) return;
      _applyProfile(snapshot.profile);
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _messageForError(error);
      });
    }
  }

  void _applyProfile(AccountProfile profile) {
    _profile = profile;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone;
  }

  Future<void> _save() async {
    if (_isSaving || _profile == null) return;
    if (_fullNameController.text.trim().isEmpty) {
      _showMessage('أدخل الاسم الشخصي.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final profile = await _repository.updateProfileDetails(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      _applyProfile(profile);
      await _authStore.refreshAccountProfile(force: true);
      if (!mounted) return;
      setState(() {});
      _showMessage('تم تحديث بيانات الحساب.');
    } catch (error) {
      if (mounted) {
        _showMessage(_messageForError(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final profile = _profile;
    if (profile == null ||
        _isUploadingAvatar ||
        _isDeletingAvatar ||
        _isSaving) {
      return;
    }

    setState(() => _isUploadingAvatar = true);
    MediaUploadResult? upload;
    try {
      upload = await _mediaUploadService.pickAndUpload(
        kind: MediaAssetKind.profileAvatar,
        entityId: profile.id,
      );
      if (upload == null || !mounted) return;

      final updated = await _repository.updateProfileAvatar(upload.publicUrl);
      if (!mounted) return;

      _applyProfile(updated);
      await _deleteAvatarBestEffort(
        profile.avatarUrl,
        exceptValue: upload.publicUrl,
      );
      await _authStore.refreshAccountProfile(force: true);
      if (!mounted) return;
      setState(() {});
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

  Future<void> _removeAvatar() async {
    final profile = _profile;
    final currentAvatar = profile?.avatarUrl?.trim() ?? '';
    if (profile == null ||
        currentAvatar.isEmpty ||
        _isUploadingAvatar ||
        _isDeletingAvatar ||
        _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الصورة الشخصية'),
        content: const Text('هل تريد حذف الصورة الشخصية من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAvatar = true);
    try {
      final updated = await _repository.clearProfileAvatar();
      if (!mounted) return;
      _applyProfile(updated);
      await _deleteAvatarBestEffort(currentAvatar);
      await _authStore.refreshAccountProfile(force: true);
      if (!mounted) return;
      setState(() {});
      _showMessage('تم حذف الصورة الشخصية.');
    } catch (error) {
      if (mounted) {
        _showMessage(_messageForError(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingAvatar = false);
      }
    }
  }

  Future<void> _deleteAvatarBestEffort(
    String? value, {
    String? exceptValue,
  }) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized == exceptValue?.trim()) return;
    try {
      await _mediaUploadService.deleteAsset(
        kind: MediaAssetKind.profileAvatar,
        value: normalized,
      );
    } catch (_) {
      // Storage cleanup is best effort after the profile row is safely updated.
    }
  }

  String _messageForError(Object error) {
    if (error is AccountFailure) return error.message;
    final text = error.toString();
    if (text.contains('network') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'تعذر الاتصال بالإنترنت.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('بيانات الحساب'),
        centerTitle: true,
        backgroundColor: AppColors.primaryTeal,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('تعذر تحميل بيانات الحساب.'));
    }

    final email = profile.email?.trim().isNotEmpty == true
        ? profile.email!
        : _authStore.user?.email ?? '';

    return ListView(
      key: const ValueKey<String>('account-profile-page'),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _ProfileHero(
          profile: profile,
          busy: _isUploadingAvatar || _isDeletingAvatar || _isSaving,
          onChangePhoto: _uploadAvatar,
        ),
        const SizedBox(height: 74),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey<String>(
                        'account-profile-full-name',
                      ),
                      controller: _fullNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الشخصي',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const ValueKey<String>(
                        'account-profile-phone',
                      ),
                      controller: _phoneController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InputDecorator(
                      key: const ValueKey<String>(
                        'account-profile-email',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      child: Text(
                        email.isEmpty ? 'غير محدد' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'البريد الإلكتروني مرتبط بحساب Google ولا يتم تغييره من هنا.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if ((profile.avatarUrl?.trim() ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'account-profile-delete-avatar',
                    ),
                    onPressed:
                        _isDeletingAvatar || _isUploadingAvatar || _isSaving
                            ? null
                            : _removeAvatar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: _isDeletingAvatar
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف الصورة الشخصية'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  key: const ValueKey<String>('account-profile-save'),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ التغييرات'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.busy,
    required this.onChangePhoto,
  });

  final AccountProfile profile;
  final bool busy;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return SizedBox(
      height: 154,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl),
              ),
            ),
          ),
          Positioned(
            top: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedDirectoryImage(
                      source: profile.avatarUrl,
                      bucket: 'avatars',
                      width: 120,
                      height: 120,
                      placeholder: ColoredBox(
                        color: AppColors.primarySoft,
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 58,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: -2,
                  bottom: 4,
                  child: IconButton.filled(
                    key: const ValueKey<String>(
                      'account-profile-change-avatar',
                    ),
                    tooltip: 'تغيير الصورة الشخصية',
                    onPressed: busy ? null : onChangePhoto,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.lightTeal,
                      foregroundColor: AppColors.white,
                    ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
