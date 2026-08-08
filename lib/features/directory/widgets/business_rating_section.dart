import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/auth_session_store.dart';
import '../../../core/services/business_rating_store.dart';
import '../../../core/theme/app_text_styles.dart';

class BusinessRatingSection extends StatefulWidget {
  const BusinessRatingSection({
    required this.businessId,
    super.key,
  });

  final String businessId;

  @override
  State<BusinessRatingSection> createState() => _BusinessRatingSectionState();
}

class _BusinessRatingSectionState extends State<BusinessRatingSection> {
  final BusinessRatingStore _ratingStore = BusinessRatingStore.instance;
  final AuthSessionStore _authStore = AuthSessionStore.instance;

  @override
  void initState() {
    super.initState();
    _ratingStore.addListener(_handleChanged);
    _authStore.addListener(_handleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ratingStore.load(widget.businessId);
    });
  }

  @override
  void didUpdateWidget(covariant BusinessRatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ratingStore.load(widget.businessId, force: true);
      });
    }
  }

  @override
  void dispose() {
    _ratingStore.removeListener(_handleChanged);
    _authStore.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final snapshot = _ratingStore.snapshotFor(widget.businessId);
    final averageText = snapshot.hasRatings
        ? snapshot.averageRating.toStringAsFixed(1)
        : '—';
    final countText = AppLocaleText.pick(
      context,
      ar: snapshot.ratingsCount == 1
          ? 'تقييم واحد'
          : '${snapshot.ratingsCount} تقييم',
      en: snapshot.ratingsCount == 1
          ? '1 rating'
          : '${snapshot.ratingsCount} ratings',
    );

    return Container(
      key: ValueKey<String>('business-rating-section-${widget.businessId}'),
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
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'تقييم النشاط',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (snapshot.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                averageText,
                key: const ValueKey<String>('business-rating-average'),
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  countText,
                  key: const ValueKey<String>('business-rating-count'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _authStore.isAuthenticated ? 'تقييمك' : 'سجل الدخول لتقييم النشاط',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 2,
            children: [
              for (var star = 1; star <= 5; star++)
                _RatingStarButton(
                  star: star,
                  selectedRating: snapshot.userRating,
                  enabled: !_authStore.isAccountBlocked,
                  onPressed: () => _rate(star),
                ),
            ],
          ),
          if (snapshot.userRating case final rating?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppLocaleText.pick(
                context,
                ar: 'تقييمك الحالي: $rating من 5',
                en: 'Your current rating: $rating of 5',
              ),
              key: const ValueKey<String>('business-user-rating-label'),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (snapshot.hasPendingRating) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'تم حفظ التقييم على الجهاز وسيتم مزامنته عند عودة الاتصال.',
              key: const ValueKey<String>('business-rating-pending'),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
          ] else if (snapshot.lastError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'تعذر تحديث التقييم الآن. يمكنك المحاولة لاحقًا.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rate(int rating) async {
    final result = await _ratingStore.setRating(widget.businessId, rating);
    if (!mounted) {
      return;
    }

    switch (result) {
      case BusinessRatingSubmitResult.saved:
        _showMessage('تم حفظ تقييمك.');
      case BusinessRatingSubmitResult.queuedOffline:
        _showMessage('تم حفظ تقييمك وسيتم مزامنته عند عودة الاتصال.');
      case BusinessRatingSubmitResult.requiresSignIn:
        _showMessage('سجّل الدخول أولًا حتى تتمكن من تقييم النشاط.');
      case BusinessRatingSubmitResult.blockedAccount:
        _showMessage('هذا الحساب غير متاح لإضافة تقييمات.');
      case BusinessRatingSubmitResult.invalidBusiness:
        _showMessage('التقييم غير متاح لهذا النشاط حاليًا.');
      case BusinessRatingSubmitResult.invalidRating:
        _showMessage('اختر تقييمًا من نجمة إلى خمس نجوم.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RatingStarButton extends StatelessWidget {
  const _RatingStarButton({
    required this.star,
    required this.selectedRating,
    required this.enabled,
    required this.onPressed,
  });

  final int star;
  final int? selectedRating;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final selected = star <= (selectedRating ?? 0);
    return Semantics(
      button: true,
      label: AppLocaleText.pick(
        context,
        ar: 'تقييم $star من 5',
        en: 'Rate $star out of 5',
      ),
      child: IconButton(
        key: ValueKey<String>('business-rating-star-$star'),
        tooltip: AppLocaleText.pick(
          context,
          ar: '$star من 5',
          en: '$star out of 5',
        ),
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          selected ? Icons.star_rounded : Icons.star_border_rounded,
          color: enabled ? AppColors.warning : AppColors.textMuted,
          size: 30,
        ),
      ),
    );
  }
}
