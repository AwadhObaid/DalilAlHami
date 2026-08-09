import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.onOpenSearch,
    required this.onOpenFilters,
    this.onOpenNotifications,
    this.unreadNotificationCount = 0,
    super.key,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilters;
  final VoidCallback? onOpenNotifications;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return SizedBox(
      key: const ValueKey<String>('home-hero-header'),
      height: AppSizes.homeHeaderHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 30,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primaryTeal,
                      AppColors.lightTeal,
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
                child: CustomPaint(
                  painter: const _HamiScenicPainter(),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxs,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _HeaderIconButton(
                                keyName: 'home-menu-button',
                                tooltip: AppLocaleText.pick(context,
                                    ar: 'الأقسام', en: 'Categories'),
                                icon: Icons.menu_rounded,
                                onPressed: onOpenFilters,
                              ),
                              const Spacer(),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _HeaderIconButton(
                                    keyName: 'home-notification-button',
                                    tooltip: AppLocaleText.pick(context,
                                        ar: 'الإشعارات', en: 'Notifications'),
                                    icon: unreadNotificationCount > 0
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_none_rounded,
                                    onPressed: onOpenNotifications ?? () {},
                                  ),
                                  if (unreadNotificationCount > 0)
                                    PositionedDirectional(
                                      top: -5,
                                      end: -6,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.advertisementGold,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          unreadNotificationCount > 99
                                              ? '99+'
                                              : '$unreadNotificationCount',
                                          textAlign: TextAlign.center,
                                          style:
                                              AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.advertisementInk,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Expanded(
                            child: Center(
                              child: Semantics(
                                image: true,
                                label:
                                    'دليل الحامي - دليل الأنشطة والخدمات المحلية',
                                child: Transform.translate(
                                  offset: const Offset(0, -23),
                                  child: SizedBox(
                                    key: const ValueKey<String>(
                                      'home-brand-logo',
                                    ),
                                    width: 260,
                                    height: 124,
                                    child: Image.asset(
                                      'assets/home_header_logo.png',
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.md,
            end: AppSpacing.md,
            bottom: 0,
            child: _SearchLauncher(
              onOpenSearch: onOpenSearch,
              onOpenFilters: onOpenFilters,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({
    required this.onOpenSearch,
    required this.onOpenFilters,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      height: AppSizes.homeSearchHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                key: const ValueKey<String>('home-filter-button'),
                onTap: onOpenFilters,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey<String>('home-search-launcher'),
                onTap: onOpenSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppSpacing.sm,
            ),
            child: IconButton(
              tooltip: AppLocaleText.pick(context,
                  ar: 'فتح البحث', en: 'Open search'),
              onPressed: onOpenSearch,
              icon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryDark,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.keyName,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String keyName;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return IconButton(
      key: ValueKey<String>(keyName),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.12),
        foregroundColor: AppColors.white,
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 24),
    );
  }
}

class _HamiScenicPainter extends CustomPainter {
  const _HamiScenicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.76;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.white.withValues(alpha: 0.22),
          AppColors.white.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.28),
          radius: size.width * 0.34,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final wavePaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < 3; index++) {
      final y = horizon + (index * 10);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 24) {
        path.quadraticBezierTo(
          x + 12,
          y + (index.isEven ? -4 : 4),
          x + 24,
          y,
        );
      }
      canvas.drawPath(path, wavePaint);
    }

    final silhouette = Paint()..color = AppColors.white.withValues(alpha: 0.16);
    final towerX = size.width * 0.16;
    final towerWidth = math.max(30.0, size.width * 0.07);
    final towerTop = size.height * 0.28;
    final towerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        towerX,
        towerTop,
        towerWidth,
        horizon - towerTop,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(towerRect, silhouette);

    final crownPath = Path()
      ..moveTo(towerX - 3, towerTop + 5)
      ..lineTo(towerX - 3, towerTop - 10)
      ..lineTo(towerX + 5, towerTop - 10)
      ..lineTo(towerX + 5, towerTop - 3)
      ..lineTo(towerX + towerWidth * 0.42, towerTop - 3)
      ..lineTo(towerX + towerWidth * 0.42, towerTop - 12)
      ..lineTo(towerX + towerWidth * 0.62, towerTop - 12)
      ..lineTo(towerX + towerWidth * 0.62, towerTop - 3)
      ..lineTo(towerX + towerWidth - 5, towerTop - 3)
      ..lineTo(towerX + towerWidth - 5, towerTop - 10)
      ..lineTo(towerX + towerWidth + 3, towerTop - 10)
      ..lineTo(towerX + towerWidth + 3, towerTop + 5)
      ..close();
    canvas.drawPath(crownPath, silhouette);

    final buildingPath = Path()
      ..moveTo(size.width * 0.04, horizon)
      ..lineTo(size.width * 0.04, horizon - 34)
      ..lineTo(size.width * 0.1, horizon - 34)
      ..lineTo(size.width * 0.1, horizon - 49)
      ..lineTo(size.width * 0.15, horizon - 49)
      ..lineTo(size.width * 0.15, horizon)
      ..lineTo(size.width * 0.27, horizon)
      ..lineTo(size.width * 0.27, horizon - 42)
      ..lineTo(size.width * 0.35, horizon - 42)
      ..lineTo(size.width * 0.35, horizon)
      ..close();
    canvas.drawPath(buildingPath, silhouette);

    final palmPaint = Paint()
      ..color = AppColors.primaryDeep.withValues(alpha: 0.18)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    _drawPalm(
      canvas,
      Offset(size.width * 0.1, horizon),
      58,
      palmPaint,
    );
    _drawPalm(
      canvas,
      Offset(size.width * 0.31, horizon),
      48,
      palmPaint,
    );

    final locationPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.42),
      44,
      locationPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.42),
      12,
      locationPaint,
    );
  }

  void _drawPalm(
    Canvas canvas,
    Offset base,
    double height,
    Paint paint,
  ) {
    final top = Offset(base.dx - 4, base.dy - height);
    canvas.drawLine(base, top, paint);

    for (var index = 0; index < 7; index++) {
      final angle = (-math.pi * 0.92) + (index * math.pi / 6);
      final length = index == 3 ? 25.0 : 20.0;
      final end = Offset(
        top.dx + (math.cos(angle) * length),
        top.dy + (math.sin(angle) * length * 0.55),
      );
      canvas.drawLine(top, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HamiScenicPainter oldDelegate) => false;
}
