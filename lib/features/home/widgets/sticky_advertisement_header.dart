import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import 'ad_slider.dart';

class StickyAdvertisementHeader extends StatelessWidget {
  const StickyAdvertisementHeader({
    required this.controller,
    required this.advertisements,
    super.key,
  });

  final PageController controller;
  final List<String> advertisements;

  @override
  Widget build(BuildContext context) {
    if (advertisements.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();
    final compactExtent = 82 + ((textScale - 1) * 34);
    final expandedExtent = 136 + ((textScale - 1) * 70);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyAdvertisementDelegate(
        controller: controller,
        advertisements: advertisements,
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
    required this.compactExtent,
    required this.expandedExtent,
  });

  final PageController controller;
  final List<String> advertisements;
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
        oldDelegate.compactExtent != compactExtent ||
        oldDelegate.expandedExtent != expandedExtent;
  }
}
