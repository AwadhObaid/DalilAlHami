import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/media_upload_service.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/shared/widgets/admin_media_field.dart';

void main() {
  testWidgets('حقل الوسائط يقبل رابطًا يدويًا دون تجاوز التخطيط', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                child: AdminMediaField(
                  label: 'صورة الإعلان',
                  controller: controller,
                  kind: MediaAssetKind.advertisementExpanded,
                  entityId: 'new',
                  aspectRatio: 16 / 9,
                  isRequired: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final urlField = find.byKey(
      const ValueKey<String>('admin-media-url-advertisementExpanded'),
    );
    expect(urlField, findsOneWidget);
    await tester.enterText(urlField, 'https://example.com/ad.jpg');
    await tester.pump();

    expect(controller.text, 'https://example.com/ad.jpg');
    expect(tester.takeException(), isNull);
  });
}
