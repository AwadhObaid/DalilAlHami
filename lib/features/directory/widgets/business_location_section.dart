import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/location/business_location.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/launch_actions.dart';

class BusinessLocationSection extends StatelessWidget {
  const BusinessLocationSection({
    required this.location,
    required this.address,
    super.key,
  });

  final BusinessLocation location;
  final String address;

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final point = LatLng(location.latitude, location.longitude);
    return Container(
      key: const ValueKey<String>('business-location-section'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 210,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
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
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        size: 46,
                        color: AppColors.danger,
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
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primaryTeal,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        address,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  key: const ValueKey<String>(
                    'business-location-directions-action',
                  ),
                  onPressed: () => LaunchActions.openDirections(
                    context,
                    latitude: location.latitude,
                    longitude: location.longitude,
                  ),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('فتح الاتجاهات'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
