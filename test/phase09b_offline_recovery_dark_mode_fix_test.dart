import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/constants/app_colors.dart';
import 'package:hami_guide/features/profile/widgets/business_category_dropdown.dart';
import 'package:hami_guide/features/profile/widgets/local_business_gallery_picker.dart';
import 'package:hami_guide/features/shared/widgets/business_location_picker.dart';

void main() {
  test('rating store retries pending work and preserves pending user state', () {
    final source =
        File('lib/core/services/business_rating_store.dart').readAsStringSync();

    expect(source, contains('Timer? _pendingRetryTimer'));
    expect(source, contains('Duration(seconds: 6)'));
    expect(source, contains('void _schedulePendingRetry()'));
    expect(source, contains('_schedulePendingRetry();'));
    expect(source, contains('final pendingUserRating = _pendingRatings[accountKey]'));
    expect(source, contains('final pendingRating ='));
    expect(source, contains('if (!synced)'));
  });

  test('owned business profile uses adaptive semantic surfaces', () {
    final source = File('lib/features/profile/profile_page.dart').readAsStringSync();

    expect(source, contains('fillColor: AppColors.surfaceMuted'));
    expect(source, contains('color: AppColors.textPrimary'));
    expect(source, contains('color: AppColors.textSecondary'));
    expect(source, contains('backgroundColor: AppColors.surfaceMuted'));
    expect(source, isNot(contains('fillColor: Colors.grey[50]')));
    expect(source, isNot(contains('color: Colors.black87')));
  });

  testWidgets('profile helper cards follow dark Material brightness', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: ListView(
            children: [
              BusinessCategoryDropdown(
                categories: const [],
                selectedCategoryId: null,
                onChanged: (_) {},
              ),
              BusinessLocationPicker(
                location: null,
                onChanged: (_) {},
              ),
              LocalBusinessGalleryPicker(
                paths: const [],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final category = tester.widget<Container>(
      find.byKey(const ValueKey<String>('profile-business-category-field')),
    );
    final categoryDecoration = category.decoration! as BoxDecoration;
    expect(categoryDecoration.color, AppColors.surfaceMuted);

    final location = tester.widget<Container>(
      find.byKey(const ValueKey<String>('business-location-picker')),
    );
    final locationDecoration = location.decoration! as BoxDecoration;
    expect(locationDecoration.color, AppColors.surface);

    final gallery = tester.widget<Container>(
      find.byKey(const ValueKey<String>('profile-local-gallery-picker')),
    );
    final galleryDecoration = gallery.decoration! as BoxDecoration;
    expect(galleryDecoration.color, AppColors.surface);
  });
}
