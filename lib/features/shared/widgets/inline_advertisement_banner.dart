import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/directory_advertisement.dart';
import 'cached_directory_image.dart';

class InlineAdvertisementBanner extends StatefulWidget {
  const InlineAdvertisementBanner({
    required this.advertisements,
    this.onOpen,
    super.key,
  });

  final List<DirectoryAdvertisement> advertisements;
  final ValueChanged<DirectoryAdvertisement>? onOpen;

  @override
  State<InlineAdvertisementBanner> createState() =>
      _InlineAdvertisementBannerState();
}

class _InlineAdvertisementBannerState extends State<InlineAdvertisementBanner> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant InlineAdvertisementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.advertisements.length) {
      _currentPage = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    if (widget.advertisements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fallbackWidth =
              MediaQuery.sizeOf(context).width - (AppSpacing.md * 2);
          final bannerWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : fallbackWidth;
          final imageWidth = _imageWidthFor(bannerWidth);
          final height = _requiredHeight(
            context,
            bannerWidth: bannerWidth,
            imageWidth: imageWidth,
          );

          return SizedBox(
            key: const ValueKey<String>('inline-advertisement-banner'),
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.advertisementGold),
                boxShadow: AppShadows.subtle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: widget.advertisements.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final advertisement = widget.advertisements[index];
                        return _InlineAdvertisementPage(
                          advertisement: advertisement,
                          imageWidth: imageWidth,
                          onOpen: widget.onOpen == null
                              ? null
                              : () => widget.onOpen!(advertisement),
                        );
                      },
                    ),
                    if (widget.advertisements.length > 1)
                      PositionedDirectional(
                        start: AppSpacing.sm,
                        bottom: AppSpacing.xs,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List<Widget>.generate(
                            widget.advertisements.length,
                            (index) => Container(
                              width: index == _currentPage ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsetsDirectional.only(
                                end: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: index == _currentPage
                                    ? AppColors.primaryTeal
                                    : AppColors.outlineStrong,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _imageWidthFor(double bannerWidth) {
    if (bannerWidth < 300) return 88;
    if (bannerWidth < 360) return 96;
    return 112;
  }

  double _requiredHeight(
    BuildContext context, {
    required double bannerWidth,
    required double imageWidth,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final hasOpenAction = widget.advertisements.any(_canOpen);
    final trailingWidth = hasOpenAction ? 17 + AppSpacing.sm : 0;
    final contentWidth = math
        .max(
          72.0,
          bannerWidth - imageWidth - trailingWidth - (AppSpacing.sm * 3),
        )
        .toDouble();

    final badgeHeight = _measureTextHeight(
          'إعلان',
          style: AppTextStyles.labelSmall,
          maxWidth: contentWidth,
          maxLines: 1,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        ) +
        (AppSpacing.xxs * 2);

    var titleHeight = 0.0;
    for (final advertisement in widget.advertisements) {
      final measuredTitleHeight = _measureTextHeight(
        advertisement.title,
        style: AppTextStyles.titleMedium,
        maxWidth: contentWidth,
        maxLines: 2,
        textScaler: textScaler,
        textDirection: textDirection,
        locale: locale,
      );
      titleHeight = math.max(titleHeight, measuredTitleHeight).toDouble();
    }

    final actionHeight = hasOpenAction
        ? _measureTextHeight(
            'اضغط لعرض التفاصيل',
            style: AppTextStyles.bodySmall,
            maxWidth: contentWidth,
            maxLines: 1,
            textScaler: textScaler,
            textDirection: textDirection,
            locale: locale,
          )
        : 0.0;

    final contentHeight = (AppSpacing.sm * 2) +
        badgeHeight +
        AppSpacing.xs +
        titleHeight +
        (hasOpenAction ? AppSpacing.xxs + actionHeight : 0);
    final indicatorReserve =
        widget.advertisements.length > 1 ? AppSpacing.sm : 0.0;
    final minimumHeight = bannerWidth < 300 ? 132.0 : 124.0;

    return math
        .max(
          minimumHeight,
          contentHeight + indicatorReserve + 2,
        )
        .toDouble();
  }

  bool _canOpen(DirectoryAdvertisement advertisement) {
    return widget.onOpen != null &&
        ((advertisement.businessId?.isNotEmpty ?? false) ||
            (advertisement.targetUrl?.isNotEmpty ?? false));
  }

  double _measureTextHeight(
    String text, {
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale? locale,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }
}

class _InlineAdvertisementPage extends StatelessWidget {
  const _InlineAdvertisementPage({
    required this.advertisement,
    required this.imageWidth,
    this.onOpen,
  });

  final DirectoryAdvertisement advertisement;
  final double imageWidth;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final canOpen = onOpen != null &&
        ((advertisement.businessId?.isNotEmpty ?? false) ||
            (advertisement.targetUrl?.isNotEmpty ?? false));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('inline-advertisement-${advertisement.id}'),
        onTap: canOpen ? onOpen : null,
        child: Row(
          children: [
            SizedBox(
              width: imageWidth,
              height: double.infinity,
              child: CachedDirectoryImage(
                source: advertisement.imagePath,
                bucket: 'advertisements',
                fit: BoxFit.cover,
                placeholder: ColoredBox(
                  color: AppColors.advertisementGoldSoft,
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 38,
                    color: AppColors.advertisementInk,
                  ),
                ),
                errorWidget: ColoredBox(
                  color: AppColors.advertisementGoldSoft,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.advertisementInk,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.advertisementGoldSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'إعلان',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.advertisementInk,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      advertisement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    if (canOpen) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'اضغط لعرض التفاصيل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canOpen)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.primaryTeal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
