import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 07D preserves the approved home and directory contracts', () {
    final home = File(
      'lib/features/home/home_dashboard_page.dart',
    ).readAsStringSync();
    final adSlider = File(
      'lib/features/home/widgets/ad_slider.dart',
    ).readAsStringSync();
    final stickyAdvertisement = File(
      'lib/features/home/widgets/sticky_advertisement_header.dart',
    ).readAsStringSync();
    final inlineAdvertisement = File(
      'lib/features/shared/widgets/inline_advertisement_banner.dart',
    ).readAsStringSync();
    final categories = File(
      'lib/features/directory/categories_overview_page.dart',
    ).readAsStringSync();
    final categoryList = File(
      'lib/features/directory/category_list_page.dart',
    ).readAsStringSync();
    final advertisementForm = File(
      'lib/features/admin/admin_advertisement_form_page.dart',
    ).readAsStringSync();
    final advertisementManagement = File(
      'lib/features/admin/admin_advertisement_management_page.dart',
    ).readAsStringSync();
    final localDatabase = File(
      'lib/data/local/database/local_directory_database.dart',
    ).readAsStringSync();

    expect(home, contains('HomeHeader('));
    expect(home, contains('onOpenSearch: widget.onOpenSearch'));
    expect(home, contains('onOpenFilters:'));
    expect(home, contains("advertisementsForPlacement('home_top')"));
    expect(home, contains("advertisementsForPlacement('home_middle')"));
    expect(home, contains('StickyAdvertisementHeader('));
    expect(home, contains('const AllBusinessesPage()'));
    expect(home, contains('onViewAll: _openAllBusinesses'));
    expect(home, contains("'home-explore-directory-footer'"));
    expect(home, contains('SliverFillRemaining('));

    expect(adSlider, contains('final ValueChanged<int>? onAdvertisementTap'));
    expect(adSlider, contains('home-advertisement-action-'));

    expect(
      stickyAdvertisement,
      contains('AppSizes.homeAdExpandedHeight'),
    );
    expect(
      stickyAdvertisement,
      contains('AppSizes.homeAdCompactHeight'),
    );
    expect(stickyAdvertisement, isNot(contains('final expandedExtent = 136')));

    expect(inlineAdvertisement, contains('LayoutBuilder('));
    expect(inlineAdvertisement, contains('TextPainter('));
    expect(inlineAdvertisement, contains('_requiredHeight('));
    expect(inlineAdvertisement, isNot(contains('final height = (118')));

    expect(categories, contains('this.initialGroup'));
    expect(categories, contains('DirectorySearchField('));
    expect(categories, contains("advertisementsForPlacement('category')"));

    expect(categoryList, contains('this.categoryIcon ='));
    expect(categoryList, contains('DirectorySearchField('));
    expect(
      categoryList,
      contains("advertisementsForPlacement('business_list')"),
    );

    expect(advertisementForm, contains('initialValue: _placement'));
    expect(advertisementForm, contains('initialValue: _targetType'));
    expect(advertisementForm, isNot(contains('value: _placement,')));
    expect(advertisementForm, isNot(contains('value: _targetType,')));

    expect(
      localDatabase,
      contains('await _ensureAdvertisementSchemaV7(database)'),
    );
    expect(localDatabase, contains('static Future<bool> _tableExists('));
    expect(localDatabase, contains('static Future<bool> _columnExists('));
    expect(localDatabase, contains('static Future<void> _addColumnIfMissing('));
    expect(
      localDatabase,
      isNot(
        contains(
          "'ALTER TABLE \$_advertisementsTable ADD COLUMN business_id TEXT'",
        ),
      ),
    );

    expect(
      advertisementManagement,
      contains('initialValue: _placementFilter'),
    );
    expect(
      advertisementManagement,
      isNot(contains('value: _placementFilter,')),
    );
  });
}
