import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/profile/widgets/business_category_dropdown.dart';
import 'package:hami_guide/models/service_category.dart';

const _categoryOne = ServiceCategory(
  id: 'category-1',
  name: 'مطاعم',
  slug: 'restaurants',
  iconName: 'restaurant',
  sortOrder: 1,
  displayGroup: CategoryDisplayGroup.services,
);

const _categoryOneReloaded = ServiceCategory(
  id: 'category-1',
  name: 'مطاعم محدثة',
  slug: 'restaurants',
  iconName: 'restaurant',
  sortOrder: 1,
  displayGroup: CategoryDisplayGroup.services,
  syncVersion: 2,
);

const _categoryTwo = ServiceCategory(
  id: 'category-2',
  name: 'متاجر',
  slug: 'shops',
  iconName: 'storefront',
  sortOrder: 2,
  displayGroup: CategoryDisplayGroup.services,
);

Widget _app({
  required List<ServiceCategory> categories,
  required String? selectedCategoryId,
  ValueChanged<String?>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BusinessCategoryDropdown(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets(
    'يعتمد اختيار تصنيف النشاط على المعرّف بعد إعادة تحميل الكائنات',
    (tester) async {
      await tester.pumpWidget(
        _app(
          categories: const [_categoryOne],
          selectedCategoryId: _categoryOne.id,
        ),
      );

      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(
                const ValueKey<String>('profile-business-category-dropdown'),
              ),
            )
            .value,
        _categoryOne.id,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app(
          categories: const [_categoryOneReloaded, _categoryTwo],
          selectedCategoryId: _categoryOne.id,
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(
                const ValueKey<String>('profile-business-category-dropdown'),
              ),
            )
            .value,
        _categoryOne.id,
      );
      expect(find.text('مطاعم محدثة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'يزيل التصنيفات المكررة حسب المعرّف دون Dropdown assertion',
    (tester) async {
      await tester.pumpWidget(
        _app(
          categories: const [
            _categoryOne,
            _categoryOneReloaded,
            _categoryTwo,
          ],
          selectedCategoryId: _categoryOne.id,
        ),
      );

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(
          const ValueKey<String>('profile-business-category-dropdown'),
        ),
      );
      expect(dropdown.items, hasLength(2));
      expect(
        dropdown.items!.where((item) => item.value == _categoryOne.id),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'القسم المحذوف أو غير الموجود يتحول إلى اختيار فارغ آمن',
    (tester) async {
      await tester.pumpWidget(
        _app(
          categories: const [_categoryOne, _categoryTwo],
          selectedCategoryId: 'deleted-category',
        ),
      );

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(
          const ValueKey<String>('profile-business-category-dropdown'),
        ),
      );
      expect(dropdown.value, isNull);
      expect(
        find.byKey(
          const ValueKey<String>('profile-business-category-unavailable'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('يعيد معرّف التصنيف عند تغييره', (tester) async {
    String? changedValue;

    await tester.pumpWidget(
      _app(
        categories: const [_categoryOne, _categoryTwo],
        selectedCategoryId: _categoryOne.id,
        onChanged: (value) => changedValue = value,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('profile-business-category-dropdown'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_categoryTwo.name).last);
    await tester.pumpAndSettle();

    expect(changedValue, _categoryTwo.id);
    expect(tester.takeException(), isNull);
  });

  test('حل التصنيف بالمعرّف يعيد كائن القائمة الحالي', () {
    final selected = BusinessCategoryDropdown.categoryForId(
      const [_categoryOneReloaded, _categoryTwo],
      _categoryOne.id,
    );

    expect(selected, same(_categoryOneReloaded));
  });
}
