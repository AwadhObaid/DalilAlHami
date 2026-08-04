import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/profile/widgets/add_business_button.dart';

void main() {
  testWidgets(
    'زر إضافة نشاط جديد يظهر وينفذ الإجراء حتى مع وجود نشاط',
    (WidgetTester tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddBusinessButton(
              buttonKey: const ValueKey<String>(
                'always-add-business-test-button',
              ),
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('إضافة نشاط جديد'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'always-add-business-test-button',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'always-add-business-test-button',
          ),
        ),
      );
      await tester.pump();

      expect(wasPressed, isTrue);
    },
  );
}
