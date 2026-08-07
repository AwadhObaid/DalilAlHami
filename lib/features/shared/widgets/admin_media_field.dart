import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/theme/app_text_styles.dart';
import 'cached_directory_image.dart';

class AdminMediaField extends StatefulWidget {
  const AdminMediaField({
    required this.label,
    required this.controller,
    required this.kind,
    required this.entityId,
    required this.aspectRatio,
    this.helperText,
    this.isRequired = false,
    this.enabled = true,
    this.uploadService,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final MediaAssetKind kind;
  final String entityId;
  final double aspectRatio;
  final String? helperText;
  final bool isRequired;
  final bool enabled;
  final MediaUploadService? uploadService;

  @override
  State<AdminMediaField> createState() => _AdminMediaFieldState();
}

class _AdminMediaFieldState extends State<AdminMediaField> {
  bool _uploading = false;
  double _progress = 0;

  MediaUploadService get _service =>
      widget.uploadService ?? MediaUploadService();

  Future<void> _pick() async {
    if (_uploading || !widget.enabled) {
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      final result = await _service.pickAndUpload(
        kind: widget.kind,
        entityId: widget.entityId,
        previousValue: widget.controller.text,
        onProgress: (value) {
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );
      if (result == null || !mounted) {
        return;
      }
      widget.controller.text = result.publicUrl;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'تم تجهيز الصورة ورفعها (${result.width}×${result.height}).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _clear() async {
    final current = widget.controller.text.trim();
    if (current.isEmpty || _uploading || !widget.enabled) {
      return;
    }

    setState(() => _uploading = true);
    try {
      await _service.deleteAsset(kind: widget.kind, value: current);
      if (!mounted) return;
      widget.controller.clear();
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final current = widget.controller.text.trim();
    return FormField<String>(
      initialValue: current,
      validator: (_) {
        if (widget.isRequired && widget.controller.text.trim().isEmpty) {
          return AppLocaleText.runtime('${widget.label} مطلوبة.');
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: AppTextStyles.titleSmall),
            if (widget.helperText != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(widget.helperText!, style: AppTextStyles.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    border: Border.all(
                      color:
                          field.hasError ? AppColors.danger : AppColors.outline,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: current.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: AppColors.primaryTeal,
                          ),
                        )
                      : CachedDirectoryImage(
                          source: current,
                          bucket: widget.kind.bucket,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            if (_uploading) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: _progress > 0 && _progress < 1 ? _progress : null,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  key: ValueKey<String>(
                    'admin-media-upload-${widget.kind.name}',
                  ),
                  onPressed: widget.enabled && !_uploading ? _pick : null,
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(current.isEmpty ? 'اختيار ورفع' : 'استبدال'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.enabled && !_uploading && current.isNotEmpty
                      ? _clear
                      : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('إزالة'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: ValueKey<String>(
                'admin-media-url-${widget.kind.name}',
              ),
              controller: widget.controller,
              enabled: widget.enabled && !_uploading,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: AppLocaleText.runtime('رابط أو مسار الصورة'),
                prefixIcon: Icon(Icons.link_rounded),
              ),
              onChanged: (_) {
                field.didChange(widget.controller.text);
                setState(() {});
              },
            ),
            if (field.hasError) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                field.errorText!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
