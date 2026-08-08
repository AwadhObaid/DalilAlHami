import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/location/business_location.dart';
import '../pages/business_location_picker_page.dart';

typedef BusinessLocationPageOpener = Future<BusinessLocation?> Function(
  BuildContext context,
  BusinessLocation? initialLocation,
);

class BusinessLocationPicker extends StatelessWidget {
  const BusinessLocationPicker({
    required this.location,
    required this.onChanged,
    this.enabled = true,
    this.pageOpener,
    super.key,
  });

  final BusinessLocation? location;
  final ValueChanged<BusinessLocation?> onChanged;
  final bool enabled;
  final BusinessLocationPageOpener? pageOpener;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) {
      return;
    }
    final selected = await (pageOpener?.call(context, location) ??
        Navigator.of(context).push<BusinessLocation>(
          MaterialPageRoute<BusinessLocation>(
            builder: (_) => BusinessLocationPickerPage(
              initialLocation: location,
            ),
          ),
        ));
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final selected = location;
    return Container(
      key: const ValueKey<String>('business-location-picker'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموقع على الخريطة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'اختياري — حدده بالنقر على الخريطة أو باستخدام موقع الهاتف.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selected == null)
            Text(
              'لم يتم تحديد موقع جغرافي.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    selected.coordinatesLabel,
                    key: const ValueKey<String>(
                      'business-location-coordinates',
                    ),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey<String>(
                    'business-location-map-action',
                  ),
                  onPressed: enabled ? () => _openPicker(context) : null,
                  icon: Icon(
                    selected == null
                        ? Icons.add_location_alt_rounded
                        : Icons.edit_location_alt_rounded,
                  ),
                  label: Text(
                    selected == null ? 'تحديد على الخريطة' : 'تعديل الموقع',
                  ),
                ),
              ),
              if (selected != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const ValueKey<String>(
                    'business-location-clear-action',
                  ),
                  tooltip: AppLocaleText.runtime('إزالة الموقع'),
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.location_off_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
