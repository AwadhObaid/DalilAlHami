class BusinessLocation {
  const BusinessLocation({
    required this.latitude,
    required this.longitude,
  })  : assert(latitude >= -90 && latitude <= 90),
        assert(longitude >= -180 && longitude <= 180);

  static const BusinessLocation alHamiCenter = BusinessLocation(
    latitude: 14.80933,
    longitude: 49.82983,
  );

  final double latitude;
  final double longitude;

  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  static BusinessLocation? fromNullable(
    Object? latitude,
    Object? longitude,
  ) {
    if (latitude == null && longitude == null) {
      return null;
    }

    final parsedLatitude = _readDouble(latitude);
    final parsedLongitude = _readDouble(longitude);
    if (parsedLatitude == null ||
        parsedLongitude == null ||
        !isValidLatitude(parsedLatitude) ||
        !isValidLongitude(parsedLongitude)) {
      return null;
    }

    return BusinessLocation(
      latitude: parsedLatitude,
      longitude: parsedLongitude,
    );
  }

  static void validatePair(
    double? latitude,
    double? longitude, {
    String message = 'حدد خط العرض وخط الطول معًا.',
  }) {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError(message);
    }
    if (latitude != null && !isValidLatitude(latitude)) {
      throw ArgumentError('خط العرض يجب أن يكون بين -90 و90.');
    }
    if (longitude != null && !isValidLongitude(longitude)) {
      throw ArgumentError('خط الطول يجب أن يكون بين -180 و180.');
    }
  }

  static bool isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool isValidLongitude(double value) => value >= -180 && value <= 180;

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().trim() ?? '');
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessLocation &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
