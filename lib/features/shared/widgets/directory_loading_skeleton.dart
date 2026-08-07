import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class DirectoryLoadingSkeleton extends StatelessWidget {
  const DirectoryLoadingSkeleton({
    this.itemCount = 4,
    super.key,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return ListView.separated(
      key: const ValueKey<String>('directory-loading-skeleton'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        130,
      ),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(
        height: AppSpacing.sm,
      ),
      itemBuilder: (context, index) => const _SkeletonBusinessCard(),
    );
  }
}

class CategoryLoadingSkeleton extends StatelessWidget {
  const CategoryLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;

        return GridView.builder(
          key: const ValueKey<String>('category-loading-skeleton'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            130,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.94,
          ),
          itemCount: crossAxisCount * 3,
          itemBuilder: (context, index) {
            return const _SkeletonBox(
              borderRadius: AppRadius.md,
            );
          },
        );
      },
    );
  }
}

class _SkeletonBusinessCard extends StatelessWidget {
  const _SkeletonBusinessCard();

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      height: 164,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              _SkeletonBox(
                width: 82,
                height: 82,
                borderRadius: AppRadius.md,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(height: 17, width: 150),
                    SizedBox(height: AppSpacing.sm),
                    _SkeletonBox(height: 14, width: 105),
                    SizedBox(height: AppSpacing.sm),
                    _SkeletonBox(height: 13, width: 125),
                  ],
                ),
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Expanded(
                child: _SkeletonBox(
                  height: 42,
                  borderRadius: AppRadius.sm,
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _SkeletonBox(
                  height: 42,
                  borderRadius: AppRadius.sm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = AppRadius.xs,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.45, end: 0.82),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.outline.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }
}
