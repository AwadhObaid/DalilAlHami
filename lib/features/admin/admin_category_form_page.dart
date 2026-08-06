import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_content_management.dart';
import '../../models/service_category.dart';
import '../shared/widgets/admin_media_field.dart';

typedef AdminCategorySaveAction = Future<AdminContentMutationResult> Function(
  AdminCategoryDraft draft,
);

class AdminCategoryFormPage extends StatefulWidget {
  const AdminCategoryFormPage({
    required this.onSave,
    this.initialCategory,
    super.key,
  });

  final AdminCategoryItem? initialCategory;
  final AdminCategorySaveAction onSave;

  @override
  State<AdminCategoryFormPage> createState() => _AdminCategoryFormPageState();
}

class _AdminCategoryFormPageState extends State<AdminCategoryFormPage> {
  static const List<String> _iconNames = <String>[
    'category',
    'restaurant',
    'fastfood',
    'soup_kitchen',
    'storefront',
    'content_cut',
    'build',
    'local_laundry_service',
    'home_repair_service',
    'medical_services',
    'local_pharmacy',
    'local_shipping',
    'local_taxi',
    'airport_shuttle',
    'motorcycle',
    'groups',
    'devices',
    'water_drop',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _imageController;
  late final TextEditingController _sortController;
  late String _iconName;
  late String _displayGroup;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    _nameController = TextEditingController(text: category?.name ?? '');
    _slugController = TextEditingController(text: category?.slug ?? '');
    _imageController = TextEditingController(text: category?.imageUrl ?? '');
    _sortController = TextEditingController(
      text: (category?.sortOrder ?? 0).toString(),
    );
    _iconName = _iconNames.contains(category?.iconName)
        ? category!.iconName
        : 'category';
    _displayGroup =
        category?.displayGroup == 'transport' ? 'transport' : 'services';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _imageController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await widget.onSave(
        AdminCategoryDraft(
          id: widget.initialCategory?.id,
          name: _nameController.text,
          slug: _slugController.text,
          iconName: _iconName,
          imageUrl: _imageController.text,
          sortOrder: int.tryParse(_sortController.text.trim()) ?? 0,
          displayGroup: _displayGroup,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialCategory != null;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(editing ? 'تعديل القسم' : 'إضافة قسم'),
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
          key: const ValueKey<String>('admin-save-category-button'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ القسم'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _FormIntro(editing: editing),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const ValueKey<String>('admin-category-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم القسم بالعربية',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'اكتب اسمًا واضحًا للقسم.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-category-slug-field'),
              controller: _slugController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'المعرّف الإنجليزي Slug',
                hintText: 'restaurants',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(text)) {
                  return 'استخدم حروفًا إنجليزية صغيرة وأرقامًا وشرطة فقط.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('admin-category-group-field'),
              initialValue: _displayGroup,
              decoration: const InputDecoration(
                labelText: 'مجموعة العرض',
                prefixIcon: Icon(Icons.account_tree_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'services', child: Text('الخدمات')),
                DropdownMenuItem(value: 'transport', child: Text('النقل')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _displayGroup = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('admin-category-icon-field'),
              initialValue: _iconName,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'أيقونة القسم',
                prefixIcon: Icon(Icons.emoji_symbols_rounded),
              ),
              items: _iconNames
                  .map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ServiceCategory.iconFromName(name), size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(name, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _iconName = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey<String>('admin-category-sort-field'),
              controller: _sortController,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'ترتيب الظهور',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                return number == null || number < 0
                    ? 'أدخل رقم ترتيب صحيحًا يبدأ من صفر.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AdminMediaField(
              key: const ValueKey<String>('admin-category-image-field'),
              label: 'صورة القسم',
              helperText:
                  'صورة مربعة أو قريبة من المربع؛ المقاس الموصى به 1200×1200.',
              controller: _imageController,
              kind: MediaAssetKind.category,
              entityId: widget.initialCategory?.id ?? 'new',
              aspectRatio: 1,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _FormIntro extends StatelessWidget {
  const _FormIntro({required this.editing});

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
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              editing
                  ? 'تعديل الاسم أو الترتيب ينعكس في الدليل عند دورة المزامنة التالية.'
                  : 'يُنشأ القسم نشطًا، ويمكن أرشفته لاحقًا إذا لم يكن مرتبطًا بأنشطة.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
