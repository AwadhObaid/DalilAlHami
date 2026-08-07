import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import 'ad_slider.dart';

class StickyAdvertisementHeader extends StatelessWidget {
  const StickyAdvertisementHeader({
    required this.controller,
    required this.advertisements,
    this.imagePaths = const <String?>[],
    this.compactImagePaths = const <String?>[],
    this.onAdvertisementTap,
    super.key,
  });

  final PageController controller;
  final List<String> advertisements;
  final List<String?> imagePaths;
  final List<String?> compactImagePaths;
  final ValueChanged<int>? onAdvertisementTap;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    if (advertisements.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();
    final expandedSliderHeight =
        (AppSizes.homeAdExpandedHeight + ((textScale - 1) * 104))
            .clamp(AppSizes.homeAdExpandedHeight, 252.0)
            .toDouble();
    const maximumOuterVerticalPadding = AppSpacing.xxs + AppSpacing.xs;
    const compactExtent =
        AppSizes.homeAdCompactHeight + maximumOuterVerticalPadding;
    final expandedExtent = expandedSliderHeight + maximumOuterVerticalPadding;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyAdvertisementDelegate(
        controller: controller,
        advertisements: advertisements,
        imagePaths: imagePaths,
        compactImagePaths: compactImagePaths,
        onAdvertisementTap: onAdvertisementTap,
        compactExtent: compactExtent,
        expandedExtent: expandedExtent,
      ),
    );
  }
}

class _StickyAdvertisementDelegate extends SliverPersistentHeaderDelegate {
  const _StickyAdvertisementDelegate({
    required this.controller,
    required this.advertisements,
    required this.imagePaths,
    required this.compactImagePaths,
    required this.onAdvertisementTap,
    required this.compactExtent,
    required this.expandedExtent,
  });

  final PageController controller;
  final List<String> advertisements;
  final List<String?> imagePaths;
  final List<String?> compactImagePaths;
  final ValueChanged<int>? onAdvertisementTap;
  final double compactExtent;
  final double expandedExtent;

  @override
  double get minExtent => compactExtent;

  @override
  double get maxExtent => expandedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;
    final collapseProgress = collapseRange <= 0
        ? 1.0
        : (shrinkOffset / collapseRange).clamp(0.0, 1.0).toDouble();

    return ColoredBox(
      key: const ValueKey<String>('sticky-advertisement-header'),
      color: AppColors.pageBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          overlapsContent ? AppSpacing.xs : AppSpacing.xxs,
        ),
        child: AdSlider(
          controller: controller,
          advertisements: advertisements,
          imagePaths: imagePaths,
          compactImagePaths: compactImagePaths,
          onAdvertisementTap: onAdvertisementTap,
          collapseProgress: collapseProgress,
          expandToFill: true,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyAdvertisementDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.advertisements != advertisements ||
        oldDelegate.imagePaths != imagePaths ||
        oldDelegate.compactImagePaths != compactImagePaths ||
        oldDelegate.onAdvertisementTap != onAdvertisementTap ||
        oldDelegate.compactExtent != compactExtent ||
        oldDelegate.expandedExtent != expandedExtent;
  }
}
