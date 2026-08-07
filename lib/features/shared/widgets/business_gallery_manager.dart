import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/business_gallery_repository.dart';
import '../../../models/business_gallery_image.dart';
import 'cached_directory_image.dart';

typedef BusinessGalleryLoadAction = Future<List<BusinessGalleryImage>>
    Function();
typedef BusinessGalleryAddAction = Future<List<BusinessGalleryImage>> Function(
  ValueChanged<double>? onProgress,
);
typedef BusinessGalleryImageAction = Future<List<BusinessGalleryImage>>
    Function(
  BusinessGalleryImage image,
);
typedef BusinessGalleryReorderAction = Future<List<BusinessGalleryImage>>
    Function(
  List<String> orderedIds,
);
typedef BusinessGalleryAltAction = Future<List<BusinessGalleryImage>> Function(
  BusinessGalleryImage image,
  String altText,
);

class BusinessGalleryManager extends StatefulWidget {
  const BusinessGalleryManager({
    required this.businessId,
    this.initialImages = const <BusinessGalleryImage>[],
    this.repository,
    this.loadAction,
    this.addAction,
    this.primaryAction,
    this.replaceAction,
    this.deleteAction,
    this.reorderAction,
    this.altAction,
    this.enabled = true,
    this.maxImages = 5,
    super.key,
  });

  final String businessId;
  final List<BusinessGalleryImage> initialImages;
  final BusinessGalleryRepository? repository;
  final BusinessGalleryLoadAction? loadAction;
  final BusinessGalleryAddAction? addAction;
  final BusinessGalleryImageAction? primaryAction;
  final BusinessGalleryImageAction? replaceAction;
  final BusinessGalleryImageAction? deleteAction;
  final BusinessGalleryReorderAction? reorderAction;
  final BusinessGalleryAltAction? altAction;
  final bool enabled;
  final int maxImages;

  @override
  State<BusinessGalleryManager> createState() => _BusinessGalleryManagerState();
}

class _BusinessGalleryManagerState extends State<BusinessGalleryManager> {
  late final BusinessGalleryRepository _repository;
  List<BusinessGalleryImage> _images = const <BusinessGalleryImage>[];
  bool _loading = false;
  bool _mutating = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BusinessGalleryRepository();
    _images = _sorted(widget.initialImages);
    if (widget.businessId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BusinessGalleryManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _images = _sorted(widget.initialImages);
      if (widget.businessId.trim().isNotEmpty) {
        _load();
      }
    } else if (oldWidget.initialImages != widget.initialImages &&
        !_mutating &&
        !_loading) {
      _images = _sorted(widget.initialImages);
    }
  }

  Future<void> _load() async {
    if (_loading || !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final images = await (widget.loadAction?.call() ??
          _repository.loadGallery(widget.businessId));
      if (!mounted) return;
      setState(() => _images = _sorted(images));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_mutating || _images.length >= widget.maxImages) return;
    setState(() {
      _mutating = true;
      _uploadProgress = 0;
    });
    try {
      final images = await (widget.addAction?.call(_onProgress) ??
          _repository.pickAndAddImage(
            businessId: widget.businessId,
            makePrimary: _images.isEmpty,
            onProgress: _onProgress,
          ));
      if (!mounted) return;
      setState(() => _images = _sorted(images));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _onProgress(double value) {
    if (!mounted) return;
    setState(() => _uploadProgress = value.clamp(0, 1).toDouble());
  }

  Future<void> _setPrimary(BusinessGalleryImage image) async {
    if (_mutating || image.isPrimary) return;
    await _runImageAction(
      () =>
          widget.primaryAction?.call(image) ??
          _repository.setPrimary(
            businessId: widget.businessId,
            imageId: image.id,
          ),
    );
  }

  Future<void> _replace(BusinessGalleryImage image) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _uploadProgress = 0;
    });
    try {
      final images = await (widget.replaceAction?.call(image) ??
          _repository.pickAndReplaceImage(
            businessId: widget.businessId,
            image: image,
            onProgress: _onProgress,
          ));
      if (!mounted) return;
      setState(() => _images = _sorted(images));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _delete(BusinessGalleryImage image) async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف صورة المعرض'),
        content: const Text(
          'ستُحذف الصورة من النشاط ومن التخزين. لا يمكن التراجع عن العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runImageAction(
      () =>
          widget.deleteAction?.call(image) ??
          _repository.deleteImage(
            businessId: widget.businessId,
            image: image,
          ),
    );
  }

  Future<void> _editAlt(BusinessGalleryImage image) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _BusinessGalleryAltDialog(initialText: image.altText),
    );
    if (text == null || !mounted) return;
    await _runImageAction(
      () =>
          widget.altAction?.call(image, text) ??
          _repository.updateAltText(
            businessId: widget.businessId,
            imageId: image.id,
            altText: text,
          ),
    );
  }

  Future<void> _runImageAction(
    Future<List<BusinessGalleryImage>> Function() action,
  ) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final images = await action();
      if (!mounted) return;
      setState(() => _images = _sorted(images));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_mutating || oldIndex == newIndex) return;
    final before = List<BusinessGalleryImage>.from(_images);
    final reordered = List<BusinessGalleryImage>.from(_images);
    final image = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, image);
    final normalized = <BusinessGalleryImage>[
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(sortOrder: index),
    ];
    setState(() {
      _images = List<BusinessGalleryImage>.unmodifiable(normalized);
      _mutating = true;
    });
    try {
      final ids = normalized.map((item) => item.id).toList(growable: false);
      final images = await (widget.reorderAction?.call(ids) ??
          _repository.reorder(
            businessId: widget.businessId,
            orderedImageIds: ids,
          ));
      if (!mounted) return;
      setState(() => _images = _sorted(images));
    } catch (error) {
      if (mounted) setState(() => _images = before);
      _showError(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error
        .toString()
        .replaceFirst('BusinessGalleryRepositoryFailure: ', '')
        .replaceFirst('MediaUploadException: ', '')
        .replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static List<BusinessGalleryImage> _sorted(
    Iterable<BusinessGalleryImage> images,
  ) {
    return BusinessGalleryImage.readList(
      images.map((image) => image.toMap()).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final canAdd = widget.enabled &&
        !_mutating &&
        widget.businessId.trim().isNotEmpty &&
        _images.length < widget.maxImages;

    return Container(
      key: const ValueKey<String>('business-gallery-manager'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppColors.primaryTeal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('معرض صور النشاط', style: AppTextStyles.titleMedium),
                    Text(
                      '${_images.length}/${widget.maxImages} صور — اسحب لإعادة الترتيب',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('business-gallery-add-button'),
                onPressed: canAdd ? _add : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('إضافة'),
              ),
            ],
          ),
          if (_uploadProgress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: _uploadProgress),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (widget.businessId.trim().isEmpty)
            const _GalleryMessage(
              icon: Icons.save_outlined,
              text: 'احفظ النشاط أولًا، ثم أضف صور المعرض.',
            )
          else if (_images.isEmpty)
            const _GalleryMessage(
              icon: Icons.collections_outlined,
              text: 'لم تُضف صور للمعرض بعد.',
            )
          else
            ReorderableListView.builder(
              key: const ValueKey<String>('business-gallery-reorder-list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _images.length,
              onReorderItem: widget.enabled ? _reorder : (_, __) {},
              itemBuilder: (context, index) {
                final image = _images[index];
                return _GalleryItem(
                  key: ValueKey<String>('business-gallery-${image.id}'),
                  image: image,
                  index: index,
                  enabled: widget.enabled && !_mutating,
                  onPrimary: () => _setPrimary(image),
                  onReplace: () => _replace(image),
                  onDelete: () => _delete(image),
                  onAlt: () => _editAlt(image),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BusinessGalleryAltDialog extends StatefulWidget {
  const _BusinessGalleryAltDialog({required this.initialText});

  final String initialText;

  @override
  State<_BusinessGalleryAltDialog> createState() =>
      _BusinessGalleryAltDialogState();
}

class _BusinessGalleryAltDialogState extends State<_BusinessGalleryAltDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return AlertDialog(
      title: const Text('وصف الصورة'),
      content: TextField(
        key: const ValueKey<String>('business-gallery-alt-field'),
        controller: _controller,
        maxLength: 120,
        decoration: const InputDecoration(
          hintText: 'مثال: واجهة المحل أو صالة الاستقبال',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey<String>('business-gallery-alt-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({
    required this.image,
    required this.index,
    required this.enabled,
    required this.onPrimary,
    required this.onReplace,
    required this.onDelete,
    required this.onAlt,
    super.key,
  });

  final BusinessGalleryImage image;
  final int index;
  final bool enabled;
  final VoidCallback onPrimary;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  final VoidCallback onAlt;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: CachedDirectoryImage(
                source: image.displayUrl,
                bucket: 'business-media',
                width: 76,
                height: 58,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          image.altText.trim().isEmpty
                              ? 'صورة ${index + 1}'
                              : image.altText.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall,
                        ),
                      ),
                      if (image.isPrimary)
                        const Chip(
                          label: Text('رئيسية'),
                          avatar: Icon(Icons.star_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Text('الترتيب: ${index + 1}', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey<String>('business-gallery-actions-${image.id}'),
              enabled: enabled,
              tooltip: 'خيارات الصورة',
              onSelected: (value) {
                switch (value) {
                  case 'primary':
                    onPrimary();
                    break;
                  case 'alt':
                    onAlt();
                    break;
                  case 'replace':
                    onReplace();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!image.isPrimary)
                  const PopupMenuItem(
                    value: 'primary',
                    child: Text('تعيين كصورة رئيسية'),
                  ),
                const PopupMenuItem(
                  value: 'alt',
                  child: Text('تعديل وصف الصورة'),
                ),
                const PopupMenuItem(
                  value: 'replace',
                  child: Text('استبدال الصورة'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف الصورة'),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              enabled: enabled,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.xs),
          Text(text,
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
