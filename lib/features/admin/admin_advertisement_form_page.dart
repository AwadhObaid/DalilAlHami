import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_advertisement_management.dart';
import '../../models/admin_content_management.dart';
import '../shared/widgets/admin_media_field.dart';

typedef AdminAdvertisementSaveAction = Future<AdminContentMutationResult>
    Function(AdminAdvertisementDraft draft);

class AdminAdvertisementFormPage extends StatefulWidget {
  const AdminAdvertisementFormPage({
    required this.businesses,
    required this.onSave,
    this.initialAdvertisement,
    super.key,
  });

  final List<AdminAdvertisementBusinessOption> businesses;
  final AdminAdvertisementSaveAction onSave;
  final AdminAdvertisementItem? initialAdvertisement;

  @override
  State<AdminAdvertisementFormPage> createState() =>
      _AdminAdvertisementFormPageState();
}

class _AdminAdvertisementFormPageState
    extends State<AdminAdvertisementFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _imagePathController;
  late final TextEditingController _compactImagePathController;
  late final TextEditingController _targetUrlController;
  late final TextEditingController _sortOrderController;

  late AdminAdvertisementPlacement _placement;
  late AdminAdvertisementTargetType _targetType;
  String? _businessId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  AdminAdvertisementItem? get _initial => widget.initialAdvertisement;

  @override
  void initState() {
    super.initState();
    final initial = _initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _imagePathController = TextEditingController(
      text: initial?.imagePath ?? '',
    );
    _compactImagePathController = TextEditingController(
      text: initial?.compactImagePath ?? '',
    );
    _targetUrlController = TextEditingController(
      text: initial?.targetUrl ?? '',
    );
    _sortOrderController = TextEditingController(
      text: (initial?.sortOrder ?? 0).toString(),
    );
    _placement = initial?.placement ?? AdminAdvertisementPlacement.homeTop;
    _targetType = initial?.targetType ?? AdminAdvertisementTargetType.none;
    _businessId = initial?.businessId;
    _startsAt = initial?.startsAt;
    _endsAt = initial?.endsAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imagePathController.dispose();
    _compactImagePathController.dispose();
    _targetUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || _formKey.currentState?.validate() != true) {
      return;
    }

    if (_targetType == AdminAdvertisementTargetType.business &&
        (_businessId == null || _businessId!.isEmpty)) {
      _showError('اختر النشاط الذي سيفتحه الإعلان.');
      return;
    }
    if (_endsAt != null && _startsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      _showError('يجب أن يكون وقت انتهاء الإعلان بعد وقت البداية.');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await widget.onSave(
        AdminAdvertisementDraft(
          id: _initial?.id,
          title: _titleController.text.trim(),
          imagePath: _imagePathController.text.trim(),
          compactImagePath: _compactImagePathController.text.trim(),
          placement: _placement,
          sortOrder: int.parse(_sortOrderController.text.trim()),
          targetType: _targetType,
          businessId: _targetType == AdminAdvertisementTargetType.business
              ? _businessId
              : null,
          targetUrl: _targetType == AdminAdvertisementTargetType.external
              ? _targetUrlController.text.trim()
              : null,
          startsAt: _startsAt,
          endsAt: _endsAt,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickStart() async {
    final value = await _pickDateTime(_startsAt ?? DateTime.now());
    if (value == null || !mounted) return;
    setState(() => _startsAt = value);
  }

  Future<void> _pickEnd() async {
    final base = _endsAt ??
        _startsAt?.add(const Duration(days: 7)) ??
        DateTime.now().add(const Duration(days: 7));
    final value = await _pickDateTime(base);
    if (value == null || !mounted) return;
    setState(() => _endsAt = value);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final localInitial = initial.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: localInitial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'اختر التاريخ',
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localInitial),
      helpText: 'اختر الوقت',
    );
    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String? _requiredText(String? value, String label, {int minLength = 2}) {
    final text = value?.trim() ?? '';
    if (text.length < minLength) {
      return '$label مطلوب.';
    }
    return null;
  }

  String? _validateSortOrder(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) {
      return 'اكتب ترتيبًا صحيحًا يساوي صفرًا أو أكثر.';
    }
    return null;
  }

  String? _validateTargetUrl(String? value) {
    if (_targetType != AdminAdvertisementTargetType.external) {
      return null;
    }
    final text = value?.trim() ?? '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'اكتب رابطًا صحيحًا يبدأ بـ http أو https.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final editing = _initial != null;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(editing ? 'تعديل الإعلان' : 'إضافة إعلان'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          key: const ValueKey<String>('admin-advertisement-form-list'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _FormIntro(editing: editing),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const ValueKey<String>('admin-advertisement-title-field'),
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'عنوان الإعلان',
                hintText: 'مثال: خصم خاص لزوار دليل الحامي',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) => _requiredText(value, 'عنوان الإعلان'),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminMediaField(
              key: const ValueKey<String>('admin-advertisement-image-field'),
              label: 'صورة الإعلان — العرض الكامل',
              helperText: 'المقاس الموصى به 1440×810 بنسبة 16:9.',
              controller: _imagePathController,
              kind: MediaAssetKind.advertisementExpanded,
              entityId: _initial?.id ?? 'new',
              aspectRatio: 16 / 9,
              isRequired: true,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.md),
            AdminMediaField(
              key: const ValueKey<String>(
                'admin-advertisement-compact-image-field',
              ),
              label: 'صورة الإعلان — الهيدر المصغّر',
              helperText:
                  'المقاس الموصى به 1600×360. عند تركها فارغة تستخدم الصورة الكاملة.',
              controller: _compactImagePathController,
              kind: MediaAssetKind.advertisementCompact,
              entityId: _initial?.id ?? 'new',
              aspectRatio: 40 / 9,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<AdminAdvertisementPlacement>(
              key: const ValueKey<String>(
                'admin-advertisement-placement-field',
              ),
              initialValue: _placement,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'موضع الظهور',
                prefixIcon: Icon(Icons.view_quilt_rounded),
              ),
              items: AdminAdvertisementPlacement.values
                  .map(
                    (placement) => DropdownMenuItem(
                      value: placement,
                      child: Text(
                        placement.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _placement = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>(
                'admin-advertisement-sort-order-field',
              ),
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'ترتيب الظهور',
                helperText: 'الرقم الأصغر يظهر أولًا.',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
              validator: _validateSortOrder,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('وجهة الإعلان', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<AdminAdvertisementTargetType>(
              key: const ValueKey<String>('admin-advertisement-target-type'),
              initialValue: _targetType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'نوع الوجهة',
                prefixIcon: Icon(Icons.ads_click_rounded),
              ),
              items: AdminAdvertisementTargetType.values
                  .map(
                    (target) => DropdownMenuItem<AdminAdvertisementTargetType>(
                      value: target,
                      child: Text(
                        target.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _targetType = value);
                      }
                    },
            ),
            if (_targetType == AdminAdvertisementTargetType.business) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>(
                  'admin-advertisement-business-field',
                ),
                initialValue:
                    widget.businesses.any((item) => item.id == _businessId)
                        ? _businessId
                        : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'النشاط المرتبط',
                  prefixIcon: Icon(Icons.store_mall_directory_rounded),
                ),
                items: widget.businesses
                    .map(
                      (business) => DropdownMenuItem<String>(
                        value: business.id,
                        child: Text(
                          business.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _businessId = value),
                validator: (_) => _businessId == null
                    ? 'اختر النشاط المرتبط بالإعلان.'
                    : null,
              ),
            ],
            if (_targetType == AdminAdvertisementTargetType.external) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>(
                  'admin-advertisement-target-url-field',
                ),
                controller: _targetUrlController,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الرابط الخارجي',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                validator: _validateTargetUrl,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('فترة العرض', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'اترك البداية أو النهاية فارغة لعدم تقييد ذلك الطرف من الفترة.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScheduleTile(
              key: const ValueKey<String>(
                'admin-advertisement-starts-at-field',
              ),
              icon: Icons.play_circle_outline_rounded,
              title: 'بداية العرض',
              value: _formatDateTime(_startsAt),
              onPick: _saving ? null : _pickStart,
              onClear: _saving || _startsAt == null
                  ? null
                  : () => setState(() => _startsAt = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScheduleTile(
              key: const ValueKey<String>('admin-advertisement-ends-at-field'),
              icon: Icons.stop_circle_outlined,
              title: 'نهاية العرض',
              value: _formatDateTime(_endsAt),
              onPick: _saving ? null : _pickEnd,
              onClear: _saving || _endsAt == null
                  ? null
                  : () => setState(() => _endsAt = null),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryTeal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      editing
                          ? 'تعديل الإعلان لا يغيّر حالة تفعيله الحالية. استخدم زر التفعيل أو الإيقاف من قائمة الإعلانات.'
                          : 'يُنشأ الإعلان مفعّلًا، ويظهر فقط عندما يحين وقت البداية وفي الموضع المدعوم داخل التطبيق.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: FilledButton.icon(
          key: const ValueKey<String>('admin-save-advertisement-button'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعلان'),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'غير محدد';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} — '
        '${two(local.hour)}:${two(local.minute)}';
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppColors.primaryTeal,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'تحديث الإعلان' : 'إعلان جديد',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'حدد المحتوى والوجهة وفترة العرض وترتيب الظهور.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(value, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'اختيار',
            onPressed: onPick,
            icon: const Icon(Icons.edit_calendar_rounded),
          ),
          IconButton(
            tooltip: 'مسح',
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ),
    );
  }
}
