import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/media_upload_service.dart';

class CachedDirectoryImage extends StatelessWidget {
  const CachedDirectoryImage({
    required this.source,
    required this.bucket,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    super.key,
  });

  final String? source;
  final String bucket;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveSource(source, bucket: bucket);
    final fallback = placeholder ?? _defaultPlaceholder();
    if (resolved.isEmpty) {
      return SizedBox(width: width, height: height, child: fallback);
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: fallback,
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: errorWidget ?? fallback,
      ),
    );
  }

  static String resolveSource(
    String? source, {
    required String bucket,
  }) {
    final value = source?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }
    return MediaUploadService.resolvePublicValue(
      value: value,
      bucket: bucket,
    );
  }

  Widget _defaultPlaceholder() {
    return const ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.primaryTeal,
        ),
      ),
    );
  }
}
