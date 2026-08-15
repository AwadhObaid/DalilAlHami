import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/location/business_location.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_content_management.dart';
import '../../models/business_contact_draft.dart';
import '../shared/widgets/admin_media_field.dart';
import '../shared/widgets/business_contact_editor.dart';
import '../shared/widgets/business_gallery_manager.dart';
import '../shared/widgets/business_location_picker.dart';

typedef AdminBusinessSaveAction = Future<AdminContentMutationResult> Function(
  AdminBusinessDraft draft,
);

class AdminBusinessFormPage extends StatefulWidget {
  const AdminBusinessFormPage({
    required this.categories,
    required this.onSave,
    this.initialBusiness,
    super.key,
  });

  final List<AdminCategoryItem> categories;
  final AdminBusinessItem? initialBusiness;
  final AdminBusinessSaveAction onSave;

  @override
  State<AdminBusinessFormPage> createState() => _AdminBusinessFormPageState();
}

class _AdminBusinessFormPageState extends State<AdminBusinessFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  List<BusinessContactDraft> _contactDrafts = <BusinessContactDraft>[
    BusinessContactDraft.emptyPrimary(),
  ];
  int _contactEditorRevision = 0;
  late final TextEditingController _addressController;
  late final TextEditingController _logoController;
  late final TextEditingController _coverController;
  String? _categoryId;
  BusinessLocation? _businessLocation;
  bool _saving = false;

  List<AdminCategoryItem> get _activeCategories => widget.categories
      .where((category) => !category.isArchived)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final business = widget.initialBusiness;
    _nameController = TextEditingController(text: business?.name ?? '');
    _descriptionController =
        TextEditingController(text: business?.description ?? '');
    _phoneController = TextEditingController(text: business?.phone ?? '');
    _whatsappController = TextEditingController(text: business?.whatsapp ?? '');
    _contactDrafts = BusinessContactDraft.fromExisting(
      contacts: business?.contactNumbers ?? const [],
      legacyPhone: business?.phone ?? '',
      legacyWhatsApp: business?.whatsapp ?? '',
    );
    _contactEditorRevision++;
    _addressController =
        TextEditingController(text: business?.address ?? 'الحامي');
    _businessLocation = BusinessLocation.fromNullable(
      business?.latitude,
      business?.longitude,
    );
    _logoController = TextEditingController(text: business?.logoUrl ?? '');
    _coverController = TextEditingController(text: business?.coverUrl ?? '');
    final activeIds = _activeCategories.map((item) => item.id).toSet();
    _categoryId = activeIds.contains(business?.categoryId)
        ? business!.categoryId
        : _activeCategories.isNotEmpty
            ? _activeCategories.first.id
            : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _logoController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final categoryId = _categoryId;
    if (categoryId == null) {
      _showError('أضف قسمًا نشطًا قبل حفظ النشاط.');
      return;
    }

    late final List<BusinessContactDraft> contacts;
    try {
      contacts = BusinessContactDraft.normalizeAndValidate(_contactDrafts);
    } on BusinessContactDraftValidationException catch (error) {
      _showError(error.message);
      return;
    }

    _phoneController.text = BusinessContactDraft.primaryPhone(contacts);
    _whatsappController.text = BusinessContactDraft.whatsappPhone(contacts);

    setState(() => _saving = true);
    try {
      final result = await widget.onSave(
        AdminBusinessDraft(
          id: widget.initialBusiness?.id,
          categoryId: categoryId,
          name: _nameController.text,
          description: _descriptionController.text,
          phone: _phoneController.text,
          whatsapp: _whatsappController.text,
          contactNumbers: contacts,
          address: _addressController.text,
          latitude: _businessLocation?.latitude,
          longitude: _businessLocation?.longitude,
          logoUrl: _logoController.text,
          coverUrl: _coverController.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(message.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final editing = widget.initialBusiness != null;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(editing ? 'تعديل النشاط' : 'إضافة نشاط'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton.icon(
          key: const ValueKey<String>('admin-save-business-button'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ النشاط'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _BusinessFormIntro(editing: editing),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('admin-business-category-field'),
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('القسم'),
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: _activeCategories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) =>
                  value == null ? AppLocaleText.runtime('اختر القسم.') : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-name-field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('اسم النشاط'),
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? AppLocaleText.runtime('اكتب اسمًا واضحًا للنشاط.')
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            BusinessContactEditor(
              key: ValueKey<String>(
                'admin-business-contact-editor-$_contactEditorRevision',
              ),
              initialValue: _contactDrafts,
              enabled: !_saving,
              onChanged: (value) {
                _contactDrafts = value;
                _phoneController.text =
                    BusinessContactDraft.primaryPhone(value);
                _whatsappController.text =
                    BusinessContactDraft.whatsappPhone(value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-address-field'),
              controller: _addressController,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('العنوان'),
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? AppLocaleText.runtime('اكتب عنوان النشاط.')
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-description-field'),
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('الوصف'),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            BusinessLocationPicker(
              location: _businessLocation,
              enabled: !_saving,
              onChanged: (location) {
                setState(() => _businessLocation = location);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AdminMediaField(
              key: const ValueKey<String>('admin-business-logo-field'),
              label: 'شعار النشاط',
              helperText: AppLocaleText.runtime(
                  'صورة مربعة؛ المقاس الموصى به 1024×1024.'),
              controller: _logoController,
              kind: MediaAssetKind.businessLogo,
              entityId: widget.initialBusiness?.id ?? 'new',
              aspectRatio: 1,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.md),
            AdminMediaField(
              key: const ValueKey<String>('admin-business-cover-field'),
              label: 'صورة غلاف النشاط',
              helperText: AppLocaleText.runtime(
                  'المقاس الموصى به 1600×900 بنسبة 16:9.'),
              controller: _coverController,
              kind: MediaAssetKind.businessCover,
              entityId: widget.initialBusiness?.id ?? 'new',
              aspectRatio: 16 / 9,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.md),
            BusinessGalleryManager(
              businessId: widget.initialBusiness?.id ?? '',
              initialImages: widget.initialBusiness?.galleryImages ?? const [],
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _BusinessFormIntro extends StatelessWidget {
  const _BusinessFormIntro({required this.editing});
  final bool editing;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_rounded,
              color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              editing
                  ? 'تعديلات المدير تحفظ مباشرة وتصل إلى الأجهزة عبر المزامنة التزايدية.'
                  : 'النشاط الذي تضيفه الإدارة يُعتمد ويُنشر مباشرة دون المرور بطابور المراجعة.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
