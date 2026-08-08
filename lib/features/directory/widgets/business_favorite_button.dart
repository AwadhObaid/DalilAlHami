import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/favorite_store.dart';

class BusinessFavoriteButton extends StatelessWidget {
  const BusinessFavoriteButton({
    required this.businessId,
    this.outlined = false,
    this.size = 20,
    super.key,
  });

  final String businessId;
  final bool outlined;
  final double size;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final store = FavoriteStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final selected = store.isFavorite(businessId);
        final tooltip = AppLocaleText.pick(
          context,
          ar: selected ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          en: selected ? 'Remove from favorites' : 'Add to favorites',
        );

        final icon = Icon(
          selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: size,
          color: selected ? AppColors.danger : null,
        );

        if (outlined) {
          return IconButton.outlined(
            key: ValueKey<String>('favorite-toggle-$businessId'),
            tooltip: tooltip,
            onPressed: () {
              store.toggleFavorite(businessId);
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(38, 38),
              side: BorderSide(color: AppColors.outline),
              foregroundColor: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
            icon: icon,
          );
        }

        return IconButton(
          key: ValueKey<String>('favorite-toggle-$businessId'),
          tooltip: tooltip,
          onPressed: () {
            store.toggleFavorite(businessId);
          },
          icon: icon,
        );
      },
    );
  }
}
