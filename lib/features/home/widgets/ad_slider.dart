import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/widgets/cached_directory_image.dart';

class AdSlider extends StatefulWidget {
  const AdSlider({
    required this.controller,
    required this.advertisements,
    this.imagePaths = const <String?>[],
    this.compactImagePaths = const <String?>[],
    this.onAdvertisementTap,
    this.collapseProgress = 0,
    this.expandToFill = false,
    super.key,
  });

  final PageController controller;
  final List<String> advertisements;
  final List<String?> imagePaths;
  final List<String?> compactImagePaths;
  final ValueChanged<int>? onAdvertisementTap;
  final double collapseProgress;
  final bool expandToFill;

  @override
  State<AdSlider> createState() => _AdSliderState();
}

class _AdSliderState extends State<AdSlider> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.advertisements.isEmpty) {
      return const SizedBox.shrink();
    }

    final progress = widget.collapseProgress.clamp(0.0, 1.0).toDouble();
    final compact = progress >= 0.55;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final sliderHeight =
        (AppSizes.homeAdExpandedHeight + ((textScale - 1) * 104))
            .clamp(AppSizes.homeAdExpandedHeight, 252.0)
            .toDouble();

    final adContent = Semantics(
      label: 'الإعلانات المحلية',
      child: Container(
        key: const ValueKey<String>('home-ad-slider'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.advertisementInk,
          borderRadius: BorderRadius.circular(
            compact ? AppRadius.md : AppRadius.lg,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: widget.controller,
              itemCount: widget.advertisements.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final expandedImage = _valueAt(widget.imagePaths, index);
                final compactImage =
                    _valueAt(widget.compactImagePaths, index) ?? expandedImage;
                return _AdvertisementPage(
                  key: ValueKey<String>(
                    compact
                        ? 'sticky-ad-compact-content'
                        : 'sticky-ad-expanded-content',
                  ),
                  message: widget.advertisements[index],
                  imagePath: compact ? compactImage : expandedImage,
                  onTap: widget.onAdvertisementTap == null
                      ? null
                      : () => widget.onAdvertisementTap!(index),
                  collapseProgress: progress,
                  variantIndex: index,
                );
              },
            ),
            if (widget.advertisements.length > 1)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: compact ? AppSpacing.xxs : AppSpacing.xs,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.advertisements.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _currentPage ? (compact ? 14 : 22) : 7,
                        height: compact ? 5 : 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? AppColors.lightTeal
                              : AppColors.white.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.expandToFill) {
      return SizedBox.expand(child: adContent);
    }

    return SizedBox(height: sliderHeight, child: adContent);
  }

  String? _valueAt(List<String?> values, int index) {
    if (index < 0 || index >= values.length) {
      return null;
    }
    final value = values[index]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class _AdvertisementPage extends StatelessWidget {
  const _AdvertisementPage({
    required this.message,
    required this.collapseProgress,
    required this.variantIndex,
    this.imagePath,
    this.onTap,
    super.key,
  });

  final String message;
  final String? imagePath;
  final VoidCallback? onTap;
  final double collapseProgress;
  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0).toDouble();
    final compact = progress >= 0.55;
    final visual = _AdvertisementVisual.forIndex(variantIndex);
    final content = Stack(
      fit: StackFit.expand,
      children: [
        _AdvertisementBackground(
          imagePath: imagePath,
          visual: visual,
          compact: compact,
        ),
        if (compact)
          _CompactAdvertisementContent(
            message: message,
            visual: visual,
          )
        else
          _ExpandedAdvertisementContent(
            message: message,
            visual: visual,
            hasImage: imagePath?.trim().isNotEmpty ?? false,
          ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('home-advertisement-action-$variantIndex'),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _AdvertisementBackground extends StatelessWidget {
  const _AdvertisementBackground({
    required this.imagePath,
    required this.visual,
    required this.compact,
  });

  final String? imagePath;
  final _AdvertisementVisual visual;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath?.trim().isNotEmpty ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          CachedDirectoryImage(
            source: imagePath,
            bucket: 'advertisements',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            placeholder: _gradient(),
            errorWidget: _gradient(),
          )
        else
          _gradient(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: hasImage
                  ? [
                      AppColors.advertisementInk.withValues(
                        alpha: compact ? 0.78 : 0.88,
                      ),
                      AppColors.advertisementInk.withValues(
                        alpha: compact ? 0.38 : 0.22,
                      ),
                    ]
                  : [
                      Colors.transparent,
                      Colors.transparent,
                    ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: visual.gradient,
        ),
      ),
    );
  }
}

class _CompactAdvertisementContent extends StatelessWidget {
  const _CompactAdvertisementContent({
    required this.message,
    required this.visual,
  });

  final String message;
  final _AdvertisementVisual visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: AppColors.white, size: 23),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.white,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const _AdvertisementBadge(compact: true),
        ],
      ),
    );
  }
}

class _ExpandedAdvertisementContent extends StatelessWidget {
  const _ExpandedAdvertisementContent({
    required this.message,
    required this.visual,
    required this.hasImage,
  });

  final String message;
  final _AdvertisementVisual visual;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!hasImage) ...[
          PositionedDirectional(
            end: -24,
            top: -34,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          PositionedDirectional(
            end: AppSpacing.xl,
            bottom: AppSpacing.lg,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(visual.icon, color: AppColors.white, size: 64),
              ),
            ),
          ),
        ],
        Positioned.fill(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              hasImage ? AppSpacing.lg : 154,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdvertisementBadge(compact: false),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.white,
                              height: 1.2,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'إعلان محلي تديره إدارة دليل الحامي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withValues(alpha: 0.9),
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.advertisementGold,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'اكتشف الآن',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.advertisementInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvertisementBadge extends StatelessWidget {
  const _AdvertisementBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.advertisementGold,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'إعلان',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.advertisementInk,
        ),
      ),
    );
  }
}

class _AdvertisementVisual {
  const _AdvertisementVisual({
    required this.gradient,
    required this.icon,
  });

  final List<Color> gradient;
  final IconData icon;

  static _AdvertisementVisual forIndex(int index) {
    return switch (index % 3) {
      1 => const _AdvertisementVisual(
          gradient: [
            Color(0xFF0B5960),
            Color(0xFF008F84),
            Color(0xFF2AB99E),
          ],
          icon: Icons.construction_rounded,
        ),
      2 => const _AdvertisementVisual(
          gradient: [
            Color(0xFF173F4A),
            Color(0xFF00646D),
            Color(0xFF009A8B),
          ],
          icon: Icons.storefront_rounded,
        ),
      _ => const _AdvertisementVisual(
          gradient: [
            Color(0xFF073C43),
            Color(0xFF006B70),
            Color(0xFF008F84),
          ],
          icon: Icons.restaurant_rounded,
        ),
    };
  }
}
