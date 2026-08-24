import '../../models/business.dart';

abstract final class BusinessShareLink {
  static const String host = 'dalilalhami-share.pages.dev';
  static const String _businessPathSegment = 'b';
  static const String _customScheme = 'dalilalhami';

  static Uri forBusinessId(String businessId) {
    final safeId = _safeBusinessId(businessId);
    if (safeId == null) {
      throw ArgumentError.value(
        businessId,
        'businessId',
        'Business id contains unsupported characters.',
      );
    }

    return Uri(
      scheme: 'https',
      host: host,
      pathSegments: <String>[_businessPathSegment, safeId],
    );
  }

  static String? businessIdFromUri(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);

    if (uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == host &&
        segments.length == 2 &&
        segments.first == _businessPathSegment) {
      return _safeBusinessId(segments.last);
    }

    if (uri.scheme.toLowerCase() == _customScheme &&
        uri.host.toLowerCase() == 'business' &&
        segments.length == 1) {
      return _safeBusinessId(segments.single);
    }

    return null;
  }

  static String shareMessage(Business business) {
    final location = business.displayPlace;
    final category = business.displayCategory;
    final link = forBusinessId(business.id);

    return 'اكتشف ${business.displayName} على تطبيق دليل الحامي\n'
        '$category • $location\n\n'
        'شاهد أرقام التواصل والموقع والصور وبقية التفاصيل:\n'
        '$link';
  }

  static String? _safeBusinessId(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty || candidate.length > 160) {
      return null;
    }

    final allowed = RegExp(r'^[A-Za-z0-9_-]+$');
    return allowed.hasMatch(candidate) ? candidate : null;
  }
}
