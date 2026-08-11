import 'package:flutter/material.dart' hide Text;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_contact_constants.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/launch_actions.dart';

typedef ContactAdminWhatsAppLauncher = Future<void> Function(
  BuildContext context,
  String phoneNumber, {
  String? message,
});

typedef ContactAdminVersionLoader = Future<String> Function();

enum ContactAdminCategory {
  inquiry,
  suggestion,
  report,
  technicalIssue,
  businessDataChange;

  String get arabicLabel => switch (this) {
        ContactAdminCategory.inquiry => 'استفسار',
        ContactAdminCategory.suggestion => 'اقتراح',
        ContactAdminCategory.report => 'بلاغ',
        ContactAdminCategory.technicalIssue => 'مشكلة تقنية',
        ContactAdminCategory.businessDataChange => 'طلب تعديل بيانات نشاط',
      };

  String label(BuildContext context) => switch (this) {
        ContactAdminCategory.inquiry => AppLocaleText.pick(
            context,
            ar: 'استفسار',
            en: 'Inquiry',
          ),
        ContactAdminCategory.suggestion => AppLocaleText.pick(
            context,
            ar: 'اقتراح',
            en: 'Suggestion',
          ),
        ContactAdminCategory.report => AppLocaleText.pick(
            context,
            ar: 'بلاغ',
            en: 'Report',
          ),
        ContactAdminCategory.technicalIssue => AppLocaleText.pick(
            context,
            ar: 'مشكلة تقنية',
            en: 'Technical issue',
          ),
        ContactAdminCategory.businessDataChange => AppLocaleText.pick(
            context,
            ar: 'طلب تعديل بيانات نشاط',
            en: 'Business data change request',
          ),
      };
}

class ContactAdminPage extends StatefulWidget {
  const ContactAdminPage({
    super.key,
    this.initialName,
    this.initialPhone,
    this.launcher,
    this.versionLoader,
  });

  final String? initialName;
  final String? initialPhone;
  final ContactAdminWhatsAppLauncher? launcher;
  final ContactAdminVersionLoader? versionLoader;

  @override
  State<ContactAdminPage> createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthSessionStore _authStore = AuthSessionStore.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _messageController = TextEditingController();

  ContactAdminCategory _category = ContactAdminCategory.inquiry;
  String _versionLabel = '...';
  bool _isLoadingVersion = true;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();

    final profile = _authStore.accountProfile;
    final user = _authStore.user;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};

    final detectedName = _firstNonEmpty(<String?>[
      widget.initialName,
      profile?.fullName,
      metadata['full_name']?.toString(),
      metadata['name']?.toString(),
      user?.email?.split('@').first,
    ]);

    final detectedPhone = _firstNonEmpty(<String?>[
      widget.initialPhone,
      profile?.phone,
      user?.phone,
    ]);

    _nameController = TextEditingController(text: detectedName);
    _phoneController = TextEditingController(text: detectedPhone);

    _loadVersion();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final loader = widget.versionLoader ?? _defaultVersionLoader;
      final value = (await loader()).trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = value.isEmpty ? 'غير متوفر' : value;
        _isLoadingVersion = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = 'غير متوفر';
        _isLoadingVersion = false;
      });
    }
  }

  Future<String> _defaultVersionLoader() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final buildNumber = info.buildNumber.trim();

    if (version.isEmpty) {
      return buildNumber.isEmpty ? '' : buildNumber;
    }
    return buildNumber.isEmpty ? version : '$version+$buildNumber';
  }

  Future<void> _openWhatsApp() async {
    if (_isLaunching || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final message = _buildWhatsAppMessage();

    setState(() => _isLaunching = true);
    try {
      if (widget.launcher != null) {
        await widget.launcher!(
          context,
          AppContactConstants.adminWhatsAppNumber,
          message: message,
        );
      } else {
        await LaunchActions.openWhatsApp(
          context,
          AppContactConstants.adminWhatsAppNumber,
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  String _buildWhatsAppMessage() {
    return <String>[
      'السلام عليكم،',
      'تواصل من تطبيق دليل الحامي.',
      '',
      'نوع الطلب: ${_category.arabicLabel}',
      'الاسم: ${_nameController.text.trim()}',
      'رقم الهاتف: ${_phoneController.text.trim()}',
      'إصدار التطبيق: $_versionLabel',
      '',
      'الرسالة:',
      _messageController.text.trim(),
    ].join('\n');
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) {
      return AppLocaleText.pick(
        context,
        ar: 'أدخل الاسم.',
        en: 'Enter your name.',
      );
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) {
      return AppLocaleText.pick(
        context,
        ar: 'أدخل رقم هاتف صحيحًا.',
        en: 'Enter a valid phone number.',
      );
    }
    return null;
  }

  String? _validateMessage(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) {
      return AppLocaleText.pick(
        context,
        ar: 'اكتب تفاصيل الطلب.',
        en: 'Enter the request details.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(
          AppLocaleText.pick(
            context,
            ar: 'التواصل مع الإدارة',
            en: 'Contact administration',
          ),
        ),
      ),
      body: ListView(
        key: const PageStorageKey<String>('contact-admin-list'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _buildIntroCard(),
          const SizedBox(height: AppSpacing.md),
          _buildFormCard(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      key: const ValueKey<String>('contact-admin-intro-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.whatsapp,
            foregroundColor: AppColors.white,
            child: Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.pick(
                    context,
                    ar: 'تواصل مباشر عبر واتساب',
                    en: 'Direct contact through WhatsApp',
                  ),
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppLocaleText.pick(
                    context,
                    ar: 'اختر نوع الطلب واكتب التفاصيل، وسيجهز التطبيق رسالة منظمة للإدارة.',
                    en: 'Choose the request type and enter the details. The app will prepare a structured message for administration.',
                  ),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ContactAdminCategory>(
              key: const ValueKey<String>('contact-admin-category-field'),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocaleText.pick(
                  context,
                  ar: 'نوع الطلب',
                  en: 'Request type',
                ),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: ContactAdminCategory.values
                  .map(
                    (category) => DropdownMenuItem<ContactAdminCategory>(
                      value: category,
                      child: Text(category.label(context)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isLaunching
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('contact-admin-name-field'),
              controller: _nameController,
              enabled: !_isLaunching,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: AppLocaleText.pick(
                  context,
                  ar: 'الاسم',
                  en: 'Name',
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('contact-admin-phone-field'),
              controller: _phoneController,
              enabled: !_isLaunching,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: AppLocaleText.pick(
                  context,
                  ar: 'رقم الهاتف',
                  en: 'Phone number',
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('contact-admin-message-field'),
              controller: _messageController,
              enabled: !_isLaunching,
              minLines: 5,
              maxLines: 8,
              maxLength: 1200,
              decoration: InputDecoration(
                labelText: AppLocaleText.pick(
                  context,
                  ar: 'تفاصيل الطلب',
                  en: 'Request details',
                ),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.message_outlined),
              ),
              validator: _validateMessage,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _isLoadingVersion
                        ? AppLocaleText.pick(
                            context,
                            ar: 'جارٍ قراءة إصدار التطبيق…',
                            en: 'Reading app version…',
                          )
                        : AppLocaleText.pick(
                            context,
                            ar: 'سيُرفق إصدار التطبيق: $_versionLabel',
                            en: 'App version will be included: $_versionLabel',
                          ),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey<String>('contact-admin-whatsapp-button'),
              onPressed:
                  _isLaunching || _isLoadingVersion ? null : _openWhatsApp,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _isLaunching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.chat_rounded),
              label: Text(
                _isLaunching
                    ? AppLocaleText.pick(
                        context,
                        ar: 'جارٍ فتح واتساب…',
                        en: 'Opening WhatsApp…',
                      )
                    : AppLocaleText.pick(
                        context,
                        ar: 'تواصل عبر واتساب',
                        en: 'Contact via WhatsApp',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
