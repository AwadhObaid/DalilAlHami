import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';

class LocalBusinessGalleryPicker extends StatelessWidget {
  const LocalBusinessGalleryPicker({
    required this.paths,
    required this.onChanged,
    this.enabled = true,
    this.picker,
    this.maxImages = 5,
    super.key,
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final ImagePicker? picker;
  final int maxImages;

  Future<void> _pick(BuildContext context) async {
    if (!enabled || paths.length >= maxImages) return;
    final selected = await (picker ?? ImagePicker()).pickMultiImage(
      imageQuality: 100,
      requestFullMetadata: false,
    );
    if (selected.isEmpty) return;

    final merged = <String>[
      ...paths,
      ...selected.map((image) => image.path),
    ];
    final unique = <String>[];
    for (final path in merged) {
      final value = path.trim();
      if (value.isEmpty || unique.contains(value)) continue;
      unique.add(value);
      if (unique.length == maxImages) break;
    }
    onChanged(List<String>.unmodifiable(unique));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Container(
      key: const ValueKey<String>('profile-local-gallery-picker'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صور معرض النشاط',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'يمكن إضافة حتى 5 صور، وتُرفع عند المزامنة.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text('${paths.length}/$maxImages'),
            ],
          ),
          const SizedBox(height: 10),
          if (paths.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: paths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = paths[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 116,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => SizedBox(
                            width: 116,
                            height: 88,
                            child: ColoredBox(
                              color: AppColors.primarySoft,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: -6,
                        end: -6,
                        child: IconButton.filled(
                          key: ValueKey<String>('local-gallery-remove-$index'),
                          onPressed: enabled
                              ? () {
                                  final updated = List<String>.from(paths)
                                    ..removeAt(index);
                                  onChanged(List<String>.unmodifiable(updated));
                                }
                              : null,
                          icon: const Icon(Icons.close, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(30, 30),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لم تختر صورًا للمعرض بعد.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('profile-local-gallery-add-button'),
            onPressed: enabled && paths.length < maxImages
                ? () => _pick(context)
                : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('اختيار صور المعرض'),
          ),
        ],
      ),
    );
  }
}
