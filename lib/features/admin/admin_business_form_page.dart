import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_content_management.dart';

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
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _logoController;
  late final TextEditingController _coverController;
  String? _categoryId;
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
    _addressController =
        TextEditingController(text: business?.address ?? 'الحامي');
    _latitudeController = TextEditingController(
      text: business?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: business?.longitude?.toString() ?? '',
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
    _latitudeController.dispose();
    _longitudeController.dispose();
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
          address: _addressController.text,
          latitude: _optionalDouble(_latitudeController.text),
          longitude: _optionalDouble(_longitudeController.text),
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

  double? _optionalDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.tryParse(text);
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
              decoration: const InputDecoration(
                labelText: 'القسم',
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
              validator: (value) => value == null ? 'اختر القسم.' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم النشاط',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'اكتب اسمًا واضحًا للنشاط.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-phone-field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 5
                  ? 'أدخل رقم هاتف صحيحًا.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-whatsapp-field'),
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'واتساب — اختياري',
                prefixIcon: Icon(Icons.chat_rounded),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-address-field'),
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'اكتب عنوان النشاط.' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-description-field'),
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('الموقع الجغرافي — اختياري', style: AppTextStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key:
                        const ValueKey<String>('admin-business-latitude-field'),
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: (value) => _coordinateValidator(value, -90, 90),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey<String>(
                        'admin-business-longitude-field'),
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: (value) =>
                        _coordinateValidator(value, -180, 180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('admin-business-logo-field'),
              controller: _logoController,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط الشعار — اختياري',
                prefixIcon: Icon(Icons.image_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-business-cover-field'),
              controller: _coverController,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط صورة الغلاف — اختياري',
                prefixIcon: Icon(Icons.panorama_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String? _coordinateValidator(String? value, double min, double max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null || number < min || number > max) {
      return 'قيمة غير صحيحة.';
    }
    return null;
  }
}

class _BusinessFormIntro extends StatelessWidget {
  const _BusinessFormIntro({required this.editing});
  final bool editing;

  @override
  Widget build(BuildContext context) {
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
