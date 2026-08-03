import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/business.dart';

class BusinessImage extends StatelessWidget {
  const BusinessImage({
    required this.business,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.heroEnabled = false,
    this.iconSize = 42,
    super.key,
  });

  final Business business;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool heroEnabled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: _buildImage(),
      ),
    );

    if (!heroEnabled || business.id.isEmpty) {
      return image;
    }

    return Hero(
      tag: 'business-image-${business.id}',
      child: image,
    );
  }

  Widget _buildImage() {
    final imageUrl = business.preferredImageUrl;
    if (imageUrl.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            _placeholder(),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primarySoft,
            AppColors.mintSoft,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: iconSize,
          color: AppColors.primaryTeal,
        ),
      ),
    );
  }
}
