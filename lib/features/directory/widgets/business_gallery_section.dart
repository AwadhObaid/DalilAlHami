import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/business_gallery_image.dart';
import '../../shared/widgets/cached_directory_image.dart';

class BusinessGallerySection extends StatelessWidget {
  const BusinessGallerySection({
    required this.images,
    super.key,
  });

  final List<BusinessGalleryImage> images;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final visibleImages = BusinessGalleryImage.readList(
      images.map((image) => image.toMap()).toList(growable: false),
    );
    if (visibleImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey<String>('business-public-gallery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined,
                color: AppColors.primaryTeal),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('معرض الصور', style: AppTextStyles.titleMedium),
            ),
            Text(
              '${visibleImages.length} صور',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 132,
          child: ListView.separated(
            key: const ValueKey<String>('business-public-gallery-list'),
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: EdgeInsets.zero,
            itemCount: visibleImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final image = visibleImages[index];
              return Semantics(
                button: true,
                label: image.altText.trim().isEmpty
                    ? 'فتح صورة النشاط رقم ${index + 1}'
                    : 'فتح صورة ${image.altText.trim()}',
                child: InkWell(
                  key: ValueKey<String>(
                      'business-gallery-thumbnail-${image.id}'),
                  onTap: () => _openViewer(context, visibleImages, index),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      children: [
                        CachedDirectoryImage(
                          source: image.displayUrl,
                          bucket: 'business-media',
                          width: 176,
                          height: 132,
                          memCacheWidth: 528,
                          memCacheHeight: 396,
                        ),
                        if (image.isPrimary)
                          const PositionedDirectional(
                            top: AppSpacing.xs,
                            start: AppSpacing.xs,
                            child: _PrimaryBadge(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openViewer(
    BuildContext context,
    List<BusinessGalleryImage> images,
    int initialIndex,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _BusinessGalleryViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 15, color: AppColors.white),
            SizedBox(width: AppSpacing.xxs),
            Text('الرئيسية', style: TextStyle(color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}

class _BusinessGalleryViewer extends StatefulWidget {
  const _BusinessGalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<BusinessGalleryImage> images;
  final int initialIndex;

  @override
  State<_BusinessGalleryViewer> createState() => _BusinessGalleryViewerState();
}

class _BusinessGalleryViewerState extends State<_BusinessGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final image = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const ValueKey<String>('business-gallery-viewer'),
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.images[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: CachedDirectoryImage(
                      source: item.displayUrl,
                      bucket: 'business-media',
                      fit: BoxFit.contain,
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                image.altText.trim().isEmpty
                    ? 'صورة من معرض النشاط'
                    : image.altText.trim(),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
