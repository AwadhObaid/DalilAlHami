import 'package:flutter/material.dart' hide Text;
import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/service_category.dart';

class BusinessCategoryDropdown extends StatelessWidget {
  const BusinessCategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final Iterable<ServiceCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  static List<ServiceCategory> normalizeCategories(
    Iterable<ServiceCategory> categories,
  ) {
    final uniqueById = <String, ServiceCategory>{};

    for (final category in categories) {
      final id = category.id.trim();
      if (id.isEmpty || category.isDeleted || uniqueById.containsKey(id)) {
        continue;
      }
      uniqueById[id] = category;
    }

    return List<ServiceCategory>.unmodifiable(uniqueById.values);
  }

  static String? normalizeSelection(
    Iterable<ServiceCategory> categories,
    String? selectedCategoryId,
  ) {
    final id = selectedCategoryId?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final category in normalizeCategories(categories)) {
      if (category.id.trim() == id) {
        return id;
      }
    }

    return null;
  }

  static ServiceCategory? categoryForId(
    Iterable<ServiceCategory> categories,
    String? categoryId,
  ) {
    final normalizedId = normalizeSelection(categories, categoryId);
    if (normalizedId == null) {
      return null;
    }

    for (final category in normalizeCategories(categories)) {
      if (category.id.trim() == normalizedId) {
        return category;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    final selectableCategories = normalizeCategories(categories);
    final safeSelectedCategoryId = normalizeSelection(
      selectableCategories,
      selectedCategoryId,
    );
    final requestedCategoryId = selectedCategoryId?.trim();
    final selectionUnavailable = requestedCategoryId != null &&
        requestedCategoryId.isNotEmpty &&
        safeSelectedCategoryId == null;

    return Container(
      key: const ValueKey<String>('profile-business-category-field'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey<String>(
                'profile-business-category-dropdown',
              ),
              hint: const Text('اختر النشاط'),
              dropdownColor: AppColors.surface,
              isExpanded: true,
              value: safeSelectedCategoryId,
              items: selectableCategories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.id.trim(),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(category.name),
                  ),
                );
              }).toList(growable: false),
              onChanged: enabled ? onChanged : null,
            ),
          ),
          if (selectionUnavailable)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'التصنيف السابق غير متاح حاليًا؛ اختر تصنيفًا آخر.',
                key: ValueKey<String>(
                  'profile-business-category-unavailable',
                ),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
