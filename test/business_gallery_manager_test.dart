import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/shared/widgets/business_gallery_manager.dart';
import 'package:hami_guide/models/business_gallery_image.dart';

void main() {
  testWidgets('مدير المعرض يحمّل الصور وينفذ الإضافة الآمنة', (tester) async {
    var addCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusinessGalleryManager(
              businessId: 'business-1',
              loadAction: () async => const <BusinessGalleryImage>[],
              addAction: (onProgress) async {
                addCalled = true;
                onProgress?.call(1);
                return const <BusinessGalleryImage>[];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('business-gallery-manager')),
      findsOneWidget,
    );
    expect(find.text('لم تُضف صور للمعرض بعد.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('business-gallery-add-button')),
    );
    await tester.pumpAndSettle();

    expect(addCalled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('مدير المعرض يطلب حفظ النشاط قبل رفع الصور', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: BusinessGalleryManager(businessId: ''),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('احفظ النشاط أولًا، ثم أضف صور المعرض.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('business-gallery-add-button')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('يستبدل صورة موجودة ويحافظ على دورة حياة وصف الصورة', (
    tester,
  ) async {
    const original = BusinessGalleryImage(
      id: 'image-1',
      businessId: 'business-1',
      storagePath: 'business-1/gallery-old.jpg',
      publicUrl: 'https://example.com/gallery-old.jpg',
      altText: 'واجهة قديمة',
      sortOrder: 0,
      isPrimary: true,
    );
    const replaced = BusinessGalleryImage(
      id: 'image-1',
      businessId: 'business-1',
      storagePath: 'business-1/gallery-new.jpg',
      publicUrl: 'https://example.com/gallery-new.jpg',
      altText: 'واجهة قديمة',
      sortOrder: 0,
      isPrimary: true,
    );
    var replaceCalled = false;
    String? savedAltText;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusinessGalleryManager(
              businessId: 'business-1',
              initialImages: const [original],
              loadAction: () async => const [original],
              replaceAction: (image) async {
                replaceCalled = image.id == original.id;
                return const [replaced];
              },
              altAction: (image, altText) async {
                savedAltText = altText;
                return [replaced.copyWith(altText: altText)];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
        find.byKey(const ValueKey<String>('business-gallery-actions-image-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استبدال الصورة'));
    await tester.pumpAndSettle();
    expect(replaceCalled, isTrue);

    await tester.tap(
        find.byKey(const ValueKey<String>('business-gallery-actions-image-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل وصف الصورة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('business-gallery-alt-field')),
      'واجهة النشاط الجديدة',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('business-gallery-alt-confirm')),
    );
    await tester.pumpAndSettle();

    expect(savedAltText, 'واجهة النشاط الجديدة');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ترتيب المعرض يستخدم الفهرس المعدل من onReorderItem دون خصم إضافي',
    (tester) async {
      const first = BusinessGalleryImage(
        id: 'image-1',
        businessId: 'business-1',
        storagePath: 'business-1/first.jpg',
        sortOrder: 0,
        isPrimary: true,
      );
      const second = BusinessGalleryImage(
        id: 'image-2',
        businessId: 'business-1',
        storagePath: 'business-1/second.jpg',
        sortOrder: 1,
        isPrimary: false,
      );
      const third = BusinessGalleryImage(
        id: 'image-3',
        businessId: 'business-1',
        storagePath: 'business-1/third.jpg',
        sortOrder: 2,
        isPrimary: false,
      );
      final byId = <String, BusinessGalleryImage>{
        first.id: first,
        second.id: second,
        third.id: third,
      };
      List<String>? submittedIds;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BusinessGalleryManager(
                businessId: 'business-1',
                initialImages: const [first, second, third],
                loadAction: () async => const [first, second, third],
                reorderAction: (orderedIds) async {
                  submittedIds = List<String>.from(orderedIds);
                  return <BusinessGalleryImage>[
                    for (var index = 0; index < orderedIds.length; index++)
                      byId[orderedIds[index]]!.copyWith(sortOrder: index),
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reorderable = tester.widget<ReorderableListView>(
        find.byKey(
          const ValueKey<String>('business-gallery-reorder-list'),
        ),
      );
      expect(reorderable.onReorderItem, isNotNull);

      reorderable.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      expect(submittedIds, <String>['image-2', 'image-3', 'image-1']);
      expect(tester.takeException(), isNull);
    },
  );
}
