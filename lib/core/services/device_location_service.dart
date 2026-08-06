import 'package:geolocator/geolocator.dart';

import '../location/business_location.dart';

class DeviceLocationFailure implements Exception {
  const DeviceLocationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<BusinessLocation> currentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const DeviceLocationFailure(
        'فعّل خدمة الموقع في الهاتف ثم أعد المحاولة.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const DeviceLocationFailure(
        'لم يتم منح إذن الموقع. يمكنك تحديد الموقع بالنقر على الخريطة.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationFailure(
        'إذن الموقع مرفوض نهائيًا. افتح إعدادات التطبيق للسماح به، '
        'أو حدد الموقع بالنقر على الخريطة.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return BusinessLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
