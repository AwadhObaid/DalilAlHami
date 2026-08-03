import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class AdSlider extends StatefulWidget {
  const AdSlider({
    required this.controller,
    required this.advertisements,
    this.collapseProgress = 0,
    this.expandToFill = false,
    super.key,
  });

  final PageController controller;
  final List<String> advertisements;
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
    final sliderHeight = (116 + ((textScale - 1) * 90)).clamp(
      116.0,
      152.0,
    );

    final adContent = Semantics(
      label: 'الإعلانات',
      child: Container(
        key: const ValueKey<String>('home-ad-slider'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.lightTeal,
              AppColors.primaryTeal,
              AppColors.primaryDark,
            ],
          ),
          borderRadius: BorderRadius.circular(
            compact ? AppRadius.md : AppRadius.lg,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              left: -20,
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.09),
                ),
              ),
            ),
            Positioned(
              bottom: -45,
              right: -10,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            PageView.builder(
              controller: widget.controller,
              itemCount: widget.advertisements.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _AdvertisementPage(
                  key: ValueKey<String>(
                    compact
                        ? 'sticky-ad-compact-content'
                        : 'sticky-ad-expanded-content',
                  ),
                  message: widget.advertisements[index],
                  collapseProgress: progress,
                );
              },
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: compact ? AppSpacing.xxs : AppSpacing.xs,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.advertisements.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: index == _currentPage ? (compact ? 14 : 18) : 6,
                      height: compact ? 5 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? AppColors.white
                            : AppColors.white.withValues(alpha: 0.45),
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

    return SizedBox(
      height: sliderHeight,
      child: adContent,
    );
  }
}

class _AdvertisementPage extends StatelessWidget {
  const _AdvertisementPage({
    required this.message,
    required this.collapseProgress,
    super.key,
  });

  final String message;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0).toDouble();
    final compact = progress >= 0.55;
    final iconSize = 44 - (10 * progress);
    final horizontalPadding = 20 - (8 * progress);
    final verticalPadding = 14 - (6 * progress);
    final titleFontSize = 16 - (2 * progress);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        compact ? 13 : 24,
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_rounded,
              size: compact ? 21 : 24,
              color: AppColors.white,
            ),
          ),
          SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'إعلان',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    message,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.white,
                      fontSize: titleFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (compact) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'إعلان',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
