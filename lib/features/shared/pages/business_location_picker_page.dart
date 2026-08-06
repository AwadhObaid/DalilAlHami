import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/location/business_location.dart';
import '../../../core/services/device_location_service.dart';
import '../../../core/utils/launch_actions.dart';

typedef CurrentBusinessLocationReader = Future<BusinessLocation> Function();

class BusinessLocationPickerPage extends StatefulWidget {
  const BusinessLocationPickerPage({
    this.initialLocation,
    this.currentLocationReader,
    super.key,
  });

  final BusinessLocation? initialLocation;
  final CurrentBusinessLocationReader? currentLocationReader;

  @override
  State<BusinessLocationPickerPage> createState() =>
      _BusinessLocationPickerPageState();
}

class _BusinessLocationPickerPageState
    extends State<BusinessLocationPickerPage> {
  final MapController _mapController = MapController();
  late BusinessLocation _selectedLocation;
  bool _isReadingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? BusinessLocation.alHamiCenter;
  }

  Future<void> _useCurrentLocation() async {
    if (_isReadingCurrentLocation) {
      return;
    }
    setState(() => _isReadingCurrentLocation = true);
    try {
      final reader = widget.currentLocationReader ??
          const DeviceLocationService().currentLocation;
      final location = await reader();
      if (!mounted) {
        return;
      }
      setState(() => _selectedLocation = location);
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        17,
      );
    } on DeviceLocationFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('تعذر قراءة موقع الهاتف. حدد الموقع بالنقر على الخريطة.');
    } finally {
      if (mounted) {
        setState(() => _isReadingCurrentLocation = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(
      _selectedLocation.latitude,
      _selectedLocation.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع النشاط'),
        actions: [
          TextButton(
            key: const ValueKey<String>('location-picker-confirm-action'),
            onPressed: () => Navigator.of(context).pop(_selectedLocation),
            child: const Text(
              'اعتماد',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point,
              initialZoom: widget.initialLocation == null ? 14 : 17,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, tappedPoint) {
                setState(
                  () => _selectedLocation = BusinessLocation(
                    latitude: tappedPoint.latitude,
                    longitude: tappedPoint.longitude,
                  ),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'hami_guide',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 52,
                    height: 52,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.danger,
                      size: 48,
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => LaunchActions.openExternalUrl(
                      context,
                      'https://www.openstreetmap.org/copyright',
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            left: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLocation.coordinatesLabel,
                          key: const ValueKey<String>(
                            'location-picker-coordinates',
                          ),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey<String>(
                          'location-picker-current-action',
                        ),
                        onPressed: _isReadingCurrentLocation
                            ? null
                            : _useCurrentLocation,
                        icon: _isReadingCurrentLocation
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: const Text('موقعي'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 12,
            right: 16,
            left: 16,
            child: SafeArea(
              bottom: false,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    'اضغط على الموقع الصحيح في الخريطة ثم اختر اعتماد.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
